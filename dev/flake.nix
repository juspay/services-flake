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
      perSystem = { pkgs, lib, config, ... }:
        let
          inherit (config.pre-commit.settings.tools) commitizen;
        in
        {
          treefmt = {
            projectRoot = inputs.services-flake;
            projectRootFile = "flake.nix";
            flakeCheck = false; # pre-commit-hooks.nix checks this
            programs = {
              nixpkgs-fmt.enable = true;
            };
          };
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.just
              commitizen
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
          checks.cz-check = pkgs.runCommand "cz-check" { buildInputs = [ pkgs.git commitizen ]; } ''
            # Set pipefail option for safer bash
            set -euo pipefail
        
            export HOME=$PWD
            cp -R ${inputs.services-flake} $HOME/source

            cd $HOME/source

            # Get the number of commits in the range
            num_commits=$(git rev-list --count main..HEAD)

            # If there are commits in the range, run the check
            if [ "$num_commits" -gt 0 ]; then
              echo "Checking $num_commits commit(s)..."
              cz check --rev-range main..HEAD
            else
              echo "No commits to check."
            fi

            touch $out
          '';
        };
    };
}
