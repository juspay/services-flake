{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    cachix-push.url = "github:juspay/cachix-push";

    # CI will override `services-flake` to run checks on the latest source
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.pre-commit-hooks-nix.flakeModule
        inputs.cachix-push.flakeModule
        ./nix/pre-commit.nix
      ];
      perSystem = { self', pkgs, config, ... }: {
        treefmt = {
          projectRoot = inputs.services-flake;
          projectRootFile = "flake.nix";
          # Even though pre-commit-hooks.nix checks it, let's have treefmt-nix
          # check as well until #238 is fully resolved.
          # flakeCheck = false; # pre-commit-hooks.nix checks this
          programs = {
            nixpkgs-fmt.enable = true;
          };
        };
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
            config.treefmt.build.devShell
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
