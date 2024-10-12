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
        ./nix/pkgs.nix
      ];
      perSystem = { self', inputs', pkgs, system, lib, ... }: {
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
          builtins.listToAttrs (builtins.map mkPackageFor ([
            "${inputs.services-flake}/nix/services/apache-kafka_test.nix"
            "${inputs.services-flake}/nix/services/clickhouse/clickhouse_test.nix"
            "${inputs.services-flake}/nix/services/elasticsearch_test.nix"
            "${inputs.services-flake}/nix/services/grafana_test.nix"
            "${inputs.services-flake}/nix/services/memcached_test.nix"
            "${inputs.services-flake}/nix/services/mongodb_test.nix"
            "${inputs.services-flake}/nix/services/nginx/nginx_test.nix"
            "${inputs.services-flake}/nix/services/ollama_test.nix"
            "${inputs.services-flake}/nix/services/open-webui_test.nix"
            "${inputs.services-flake}/nix/services/pgadmin_test.nix"
            "${inputs.services-flake}/nix/services/postgres/postgres_test.nix"
            "${inputs.services-flake}/nix/services/prometheus_test.nix"
            "${inputs.services-flake}/nix/services/redis_test.nix"
            "${inputs.services-flake}/nix/services/redis-cluster_test.nix"
            "${inputs.services-flake}/nix/services/searxng_test.nix"
            "${inputs.services-flake}/nix/services/tempo_test.nix"
            "${inputs.services-flake}/nix/services/tika_test.nix"
            "${inputs.services-flake}/nix/services/weaviate_test.nix"
            "${inputs.services-flake}/nix/services/zookeeper_test.nix"
          ]));
      };
    };
}
