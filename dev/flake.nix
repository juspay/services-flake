{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # CI will override `services-flake` to run checks on the latest source
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
      perSystem = { pkgs, lib, config, ... }: {
        treefmt = {
          projectRoot = inputs.services-flake;
          projectRootFile = "flake.nix";
          programs = {
            nixpkgs-fmt.enable = true;
          };
        };
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.just
          ];
          # cf. https://flakular.in/haskell-flake/devshell#composing-devshells
          inputsFrom = [
            config.treefmt.build.devShell
          ];
          shellHook = ''
            echo
            echo "🍎🍎 Run 'just <recipe>' to get started"
            just
          '';
        };
      };
    };
}
