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
      perSystem = { self', pkgs, system, lib, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          # Required for elastic search
          config.allowUnfree = true;
        };
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
          elasticsearch = {
            imports = [
              inputs.services-flake.processComposeModules.default
              ../nix/elasticsearch_test.nix
            ];
          };
        };
      };
    };
}
