{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
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
        ./nix/pre-commit.nix
      ];
      perSystem = { pkgs, lib, config, ... }: {
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

        # TODO: Move this under `CIApps` once `omnix` supports running them automatically
        # CONSIDER: Generalise the script, see: https://github.com/juspay/services-flake/pull/338/files#r1773042527
        apps.cz-check = rec {
          meta.description = program.meta.description;
          program = pkgs.writeShellApplication {
            name = "cz-check";
            runtimeInputs = with pkgs; [ config.pre-commit.settings.tools.commitizen git gnugrep coreutils ];
            meta.description = "Verify commit messages from the default branch to HEAD follow conventional commit format";
            text = ''
              default_branch=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)

              # Get the latest commit on the default branch
              # rev range using the `default_branch` branch name (e.g. main..HEAD), doesn't work in Github Actions
              latest_default_commit=$(git rev-parse origin/"$default_branch")

              current_commit=$(git rev-parse HEAD)

              if [ "$latest_default_commit" = "$current_commit" ]; then
                  echo "No commits to check between $default_branch and HEAD."
              else
                  cz check --rev-range "$latest_default_commit"..HEAD
              fi
            '';
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
