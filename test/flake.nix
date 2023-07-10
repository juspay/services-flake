{
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
      ];
      perSystem = { self', pkgs, lib, ... }: {
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
      };
    };
}
