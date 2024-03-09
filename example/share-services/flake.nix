{
  description = "A demo of sharing services using services-flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
        ./integration-test.nix
      ];
      perSystem = { self', pkgs, lib, ... }: {

        # Run only external-services by default
        process-compose."default" = { config, ... }: {
          imports = [
            inputs.services-flake.processComposeModules.default
            ./external-services.nix
          ];
        };

      };
    };
}
