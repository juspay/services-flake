# Development flake
#
# We setup a dev environment as well as run tests (flake checks) here, such that
# the top-level flake is simple enough for users.
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";

    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "path:..";
    example.url = "path:../example";

  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { inputs', pkgs, lib, config, ... }: {
        # Test /example
        checks = inputs'.example.checks;

        # Test the individual services
        process-compose = {
          postgres = {
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/postgres_test.nix
            ];
          };
          redis = {
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/redis_test.nix
            ];
          };
        };

        mission-control.scripts = {
          ex = {
            description = "Run example";
            exec = "cd ./example && nix run . --override-input services-flake ..";
          };
          test = {
            description = "Run test";
            exec = "./test.sh";
          };
          fmt = {
            description = "Format all Nix files";
            exec = ''
              ${lib.getExe pkgs.fd} -e nix | xargs ${lib.getExe pkgs.nixpkgs-fmt}
            '';
          };
        };
        devShells.default = pkgs.mkShell {
          # cf. https://haskell.flake.page/devshell#composing-devshells
          inputsFrom = [ config.mission-control.devShell ];
        };
      };
    };
}
