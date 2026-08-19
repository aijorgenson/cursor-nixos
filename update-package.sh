#!/usr/bin/env bash
# Refresh sources.json from Cursor's Linux download API and verify the package
# still builds. No argument = latest stable. See README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_FILE="$SCRIPT_DIR/sources.json"

prefetch() {
  local url="$1"
  nix store prefetch-file --json --hash-type sha256 "$url"
}

query() {
  local platform="$1"
  curl -fsSL "https://api2.cursor.sh/updates/api/download/stable/${platform}/cursor"
}

CURRENT_VERSION=$(jq -r '.version' "$SOURCES_FILE")

X64_META=$(query linux-x64)
ARM_META=$(query linux-arm64)

X64_VERSION=$(jq -r '.version' <<< "$X64_META")
ARM_VERSION=$(jq -r '.version' <<< "$ARM_META")

if [ "$X64_VERSION" != "$ARM_VERSION" ]; then
  echo "Version mismatch between linux-x64 (${X64_VERSION}) and linux-arm64 (${ARM_VERSION})." >&2
  echo "Cursor did not publish a matching pair; refusing to update." >&2
  exit 1
fi

NEW_VERSION="$X64_VERSION"
X64_URL=$(jq -r '.downloadUrl' <<< "$X64_META")
ARM_URL=$(jq -r '.downloadUrl' <<< "$ARM_META")

if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "null" ] || [ -z "$X64_URL" ] || [ -z "$ARM_URL" ]; then
  echo "Could not parse Cursor's download API response." >&2
  exit 1
fi

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date (${CURRENT_VERSION})."
  exit 0
fi

echo "Updating cursor: ${CURRENT_VERSION} -> ${NEW_VERSION}"
echo "  x86_64-linux: ${X64_URL}"
echo "  aarch64-linux: ${ARM_URL}"

echo "Prefetching x86_64 AppImage..."
X64_JSON=$(prefetch "$X64_URL")
X64_HASH=$(jq -r '.hash' <<< "$X64_JSON")

echo "Prefetching aarch64 AppImage..."
ARM_JSON=$(prefetch "$ARM_URL")
ARM_HASH=$(jq -r '.hash' <<< "$ARM_JSON")

jq -n \
  --arg version "$NEW_VERSION" \
  --arg x64_url "$X64_URL" \
  --arg x64_hash "$X64_HASH" \
  --arg arm_url "$ARM_URL" \
  --arg arm_hash "$ARM_HASH" \
  '{
    version: $version,
    sources: {
      "x86_64-linux": { url: $x64_url, hash: $x64_hash },
      "aarch64-linux": { url: $arm_url, hash: $arm_hash }
    }
  }' > "$SOURCES_FILE"

echo "Wrote ${SOURCES_FILE}"
echo "Building package to verify..."
nix build "${SCRIPT_DIR}#default" --no-link
RESULT_PATH=$(nix build "${SCRIPT_DIR}#default" --no-link --print-out-paths)
echo "Built: ${RESULT_PATH}"
echo
echo "sources.json now points at ${NEW_VERSION}. Review the diff before committing:"
echo "  git -C \"${SCRIPT_DIR}\" diff sources.json"
