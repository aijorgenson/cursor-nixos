{
  description = "Cursor editor for NixOS, wrapping the official Linux AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );
    in
    {
      packages = forAll (pkgs: rec {
        cursor = pkgs.callPackage ./package.nix { };
        default = cursor;
      });

      overlays.default = final: prev: {
        cursor = final.callPackage ./package.nix { };
        # Same derivation under nixpkgs' name, so existing `pkgs.code-cursor`
        # references pick up this flake's faster-updating package.
        code-cursor = final.cursor;
      };

      # One-liner NixOS setup: overlay + install. You still need
      # `nixpkgs.config.allowUnfree = true` (Cursor's license is unfree).
      nixosModules.default =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlays.default ];
          environment.systemPackages = [ pkgs.cursor ];
        };
    };
}
