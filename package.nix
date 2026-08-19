{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:

let
  sourcesJson = lib.importJSON ./sources.json;
  pname = "cursor";
  inherit (sourcesJson) version;
  src =
    sourcesJson.sources.${stdenv.hostPlatform.system}
      or (throw "cursor-nixos: unsupported system ${stdenv.hostPlatform.system}");
  appimage = fetchurl { inherit (src) url hash; };
  appimageContents = appimageTools.extract {
    inherit pname version;
    src = appimage;
  };
in
appimageTools.wrapType2 {
  inherit pname version;
  src = appimage;

  # libsecret is the one Electron extra wrapType2's default FHS set does not
  # always include; Cursor uses it for login/keychain.
  extraPkgs = pkgs: [ pkgs.libsecret ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/cursor.desktop \
      $out/share/applications/cursor.desktop
    sed -i -E \
      -e 's|^Exec=cursor|Exec=cursor --update=false|' \
      -e 's|^Icon=.*|Icon=cursor|' \
      $out/share/applications/cursor.desktop

    install -Dm444 ${appimageContents}/usr/share/applications/cursor-url-handler.desktop \
      $out/share/applications/cursor-url-handler.desktop
    sed -i -E \
      -e 's|^Exec=.*|Exec=cursor --open-url %U|' \
      -e 's|^Icon=.*|Icon=cursor|' \
      $out/share/applications/cursor-url-handler.desktop

    install -Dm444 ${appimageContents}/usr/share/pixmaps/co.anysphere.cursor.png \
      $out/share/pixmaps/cursor.png

    for size in 22 24 32 48 64 128 256 512; do
      icon="${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/cursor.png"
      if [ -f "$icon" ]; then
        install -Dm444 "$icon" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/cursor.png"
      fi
    done
  '';

  meta = {
    description = "AI-powered code editor built on VS Code";
    homepage = "https://cursor.com";
    changelog = "https://cursor.com/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "cursor";
  };
}
