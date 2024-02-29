{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake = { };
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
          overlays = [
            (final: prev: {
              pgadmin4 = prev.pgadmin4.overrideAttrs (_: { doInstallCheck = false; });
            })
          ];
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
            "${inputs.services-flake}/nix/apache-kafka_test.nix"
            "${inputs.services-flake}/nix/clickhouse/clickhouse_test.nix"
            "${inputs.services-flake}/nix/elasticsearch_test.nix"
            "${inputs.services-flake}/nix/mysql_test.nix"
            "${inputs.services-flake}/nix/nginx_test.nix"
            "${inputs.services-flake}/nix/postgres/postgres_test.nix"
            "${inputs.services-flake}/nix/redis_test.nix"
            "${inputs.services-flake}/nix/redis-cluster_test.nix"
            "${inputs.services-flake}/nix/zookeeper_test.nix"
            "${inputs.services-flake}/nix/grafana_test.nix"
            "${inputs.services-flake}/nix/prometheus_test.nix"
            "${inputs.services-flake}/nix/pgadmin_test.nix"
          ]);
      };
    };
}
