{ inputs, ... }:

{
  perSystem = { self', inputs', pkgs, system, lib, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;

      # Required for elastic search
      config.allowUnfree = true;

      overlays = [
        (self: super: lib.optionalAttrs super.stdenv.isDarwin {

          # grafana is broken on aarch64-darwin, but works on older nixpkgs:
          # https://github.com/NixOS/nixpkgs/issues/273998
          grafana = (builtins.getFlake "github:nixos/nixpkgs/b604023e0a5549b65da3040a07d2beb29ac9fc63").legacyPackages.${system}.grafana;

          # Disable tests, because they are failing on darwin:
          # https://github.com/NixOS/nixpkgs/issues/281214
          pgadmin4 = super.pgadmin4.overrideAttrs (_: {
            doInstallCheck =
              false;
          });

        })
      ];
    };
  };
}
