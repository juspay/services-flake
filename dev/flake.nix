{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks-nix.flake = false;
    cachix-push.url = "github:juspay/cachix-push";

    # CI will override `services-flake` to run checks on the latest source
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        (inputs.pre-commit-hooks-nix + /flake-module.nix)
        inputs.cachix-push.flakeModule
        ./nix/pre-commit.nix
      ];
      perSystem = { self', pkgs, config, ... }: {
        cachix-push = {
          cacheName = "services-flake";
          pathsToCache = {
            devshell = self'.devShells.default;
          };
        };
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            just
            nixd
            config.pre-commit.settings.tools.commitizen
          ];
          inputsFrom = [
            config.pre-commit.devShell
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
