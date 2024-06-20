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
            "${inputs.services-flake}/nix/apache-kafka_test.nix"
            "${inputs.services-flake}/nix/clickhouse/clickhouse_test.nix"
            "${inputs.services-flake}/nix/elasticsearch_test.nix"
            "${inputs.services-flake}/nix/mysql/mysql_test.nix"
            "${inputs.services-flake}/nix/nginx/nginx_test.nix"
            "${inputs.services-flake}/nix/ollama_test.nix"
            "${inputs.services-flake}/nix/open-webui_test.nix"
            "${inputs.services-flake}/nix/postgres/postgres_test.nix"
            "${inputs.services-flake}/nix/redis_test.nix"
            "${inputs.services-flake}/nix/redis-cluster_test.nix"
            "${inputs.services-flake}/nix/zookeeper_test.nix"
            "${inputs.services-flake}/nix/prometheus_test.nix"
            "${inputs.services-flake}/nix/pgadmin_test.nix"
            "${inputs.services-flake}/nix/cassandra_test.nix"
            "${inputs.services-flake}/nix/tempo_test.nix"
            "${inputs.services-flake}/nix/weaviate_test.nix"
          ] ++ lib.optionals pkgs.stdenv.isLinux [
            # Broken on Darwin: https://github.com/NixOS/nixpkgs/issues/316954
            "${inputs.services-flake}/nix/grafana_test.nix"
            # Broken on Darwin: https://github.com/NixOS/nixpkgs/issues/321329
            "${inputs.services-flake}/nix/searxng_test.nix"
          ]));
      };
    };
}
