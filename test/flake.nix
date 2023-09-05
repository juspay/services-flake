{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:shivaraj-bh/process-compose-flake/bug-test-process";
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
        process-compose =
          let
            mkPackageFor = mod:
              let
                # Derive name from filename
                name = lib.pipe mod [
                  builtins.baseNameOf
                  (builtins.match "(.*)_test.nix")
                  builtins.head
                ];
              in
              lib.nameValuePair name {
                imports = [
                  inputs.services-flake.processComposeModules.default
                  mod
                ];
              };
          in
          builtins.listToAttrs (builtins.map mkPackageFor [
            ../nix/apache-kafka_test.nix
            ../nix/elasticsearch_test.nix
            ../nix/postgres_test.nix
            ../nix/redis_test.nix
            ../nix/redis-cluster_test.nix
            ../nix/zookeeper_test.nix
          ]);
      };
    };
}
