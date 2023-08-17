{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:shivaraj-bh/process-compose-flake/process-as-test";
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
            # TODO: remove `port = 0`; as it will be default after this: https://github.com/Platonic-Systems/process-compose-flake/pull/42
            port = 0;
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/postgres_test.nix
            ];
          };
          redis = {
            port = 0;
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/redis_test.nix
            ];
          };
          redis-cluster = {
            port = 0;
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/redis-cluster_test.nix
            ];
          };
        };
      };
    };
}
