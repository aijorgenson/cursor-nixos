# cursor-nixos

> The [Cursor](https://cursor.com) editor on NixOS, wrapping Cursor's own
> Linux AppImage. A GitHub Action bumps the pin when Cursor ships a new
> stable build, so you are not waiting on nixpkgs' `code-cursor`.

Cursor publishes Linux AppImage, `.deb`, and `.rpm` builds — not NixOS. This
flake takes the AppImage (the same artifact nixpkgs uses) and wraps it in an
FHS environment. No extra sysctls, DNS, or linger flags. The current pin is
in `sources.json`.

- [Try it without installing](#try-it-without-installing)
- [Add it to your flake](#add-it-to-your-flake)
- [Updating](#updating)
- [License](#license)

## Try it without installing

```sh
nix run github:aijorgenson/cursor --accept-flake-config
```

(`nix run` from this flake sets `allowUnfree` for the build. Cursor itself
is unfree.)

## Add it to your flake

Cursor is unfree, so your NixOS config already needs
`nixpkgs.config.allowUnfree = true`. After that, the module is one line.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cursor = {
      url = "github:aijorgenson/cursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, cursor, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        cursor.nixosModules.default
      ];
    };
  };
}
```

That overlay also aliases `pkgs.code-cursor` to this package, so you can
drop nixpkgs' copy if you already list it.

### Or just the package

```nix
{ pkgs, cursor, ... }:
{
  environment.systemPackages = [ cursor.packages.${pkgs.system}.default ];
}
```

(Pass `cursor` through `specialArgs` if the module file is not the flake's
`outputs`.)

Linux only: `x86_64-linux` and `aarch64-linux`. On Darwin, use Cursor's
official DMG.

## Updating

`sources.json` pins the AppImage URL and hash for each Linux arch. A
scheduled Action queries
[Cursor's download API](https://api2.cursor.sh/updates/api/download/stable/linux-x64/cursor)
once a day, and when the version moved, runs `./update-package.sh`, builds,
and pushes straight to `main`.

Requirements for the Action:

- **Settings → Actions → General → Workflow permissions** = "Read and write
  permissions"
- If `main` is protected, allow `github-actions[bot]` to push

Trigger it by hand from the Actions tab ("Run workflow") — same admin-only
gate as lerd-nixos.

### Manual

```sh
./update-package.sh
```

It fetches latest stable for `linux-x64` and `linux-arm64`, refuses to
update if those versions diverge, prefetches hashes, writes `sources.json`,
and `nix build`s. Nothing is committed.

## License

The Nix expressions and scripts in this repo are [MIT](LICENSE). That covers
the packaging only.

Cursor itself is proprietary (Nix `unfree`). This flake does not ship the
AppImage; Nix downloads it from Cursor at build time. Using Cursor is still
under [Anysphere’s terms](https://cursor.com/terms-of-service). This project
is unofficial and not affiliated with Anysphere.

---

> Built and tested on `x86_64-linux`.
