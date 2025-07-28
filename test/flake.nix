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
                cli = {
                  options = {
                    # HTTP server disabled by default but we need it here for tests
                    no-server = false;
                    use-uds = true;
                    unix-socket = "pc-${name}.sock";
                  };
                };
              };
          in
          builtins.listToAttrs (builtins.map mkPackageFor ([
            "${inputs.services-flake}/nix/services/cassandra_test.nix"
            "${inputs.services-flake}/nix/services/clickhouse/clickhouse_test.nix"
            "${inputs.services-flake}/nix/services/grafana_test.nix"
            "${inputs.services-flake}/nix/services/memcached_test.nix"
            "${inputs.services-flake}/nix/services/minio_test.nix"
            "${inputs.services-flake}/nix/services/nats-server_test.nix"
            "${inputs.services-flake}/nix/services/nginx/nginx_test.nix"
            "${inputs.services-flake}/nix/services/ollama_test.nix"
            "${inputs.services-flake}/nix/services/open-webui_test.nix"
            "${inputs.services-flake}/nix/services/pgadmin_test.nix"
            "${inputs.services-flake}/nix/services/plantuml_test.nix"
            "${inputs.services-flake}/nix/services/postgres/postgres_test.nix"
            "${inputs.services-flake}/nix/services/prometheus_test.nix"
            "${inputs.services-flake}/nix/services/redis_test.nix"
            "${inputs.services-flake}/nix/services/redis-cluster_test.nix"
            "${inputs.services-flake}/nix/services/searxng_test.nix"
            "${inputs.services-flake}/nix/services/tempo_test.nix"
            "${inputs.services-flake}/nix/services/tika_test.nix"
            "${inputs.services-flake}/nix/services/weaviate_test.nix"
            "${inputs.services-flake}/nix/services/zookeeper_test.nix"
          ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            # `phpfpm` test fails on aarch64-darwin:
            # [phpfpm1        ] [28-Jul-2025 13:05:47.512506] DEBUG: pid 90757, fpm_stdio_save_original_stderr(), line 81: saving original STDERR fd: dup()
            # [phpfpm1        ] [28-Jul-2025 13:05:47.512606] ERROR: pid 90757, fpm_stdio_open_error_log(), line 386: failed to open error_log (/proc/self/fd/2): No such file or directory (2)
            # [phpfpm1        ] [28-Jul-2025 13:05:47.512647] ERROR: pid 90757, fpm_conf_init_main(), line 1882: failed to post process the configuration
            # [phpfpm1        ] [28-Jul-2025 13:05:47.512661] ERROR: pid 90757, fpm_init(), line 72: FPM initialization failed
            # [phpfpm2        ] [28-Jul-2025 13:05:47] ERROR: failed to open error_log (/proc/self/fd/2): No such file or directory (2)
            # [phpfpm2        ] [28-Jul-2025 13:05:47] ERROR: failed to post process the configuration
            # [phpfpm2        ] [28-Jul-2025 13:05:47] ERROR: FPM initialization failed
            "${inputs.services-flake}/nix/services/phpfpm_test.nix"
            # `mysql80` package fails to build on aarch64-darwin with:
            # libc++abi: terminating due to uncaught exception of type std::runtime_error: opening input file: No such file or directory
            # /nix/store/w3q1nvfb44cmc0a3pdky0654ll7nca7n-signing-utils: line 24: 75907 Abort trap: 6           /nix/store/dqrpsqnanf3cr9nalcnl7pvbdwrqrwfk-sigtool-0.1.3/bin/sigtool --file "$file" check-requires-signature
            # Unexpected exit status from sigtool: 134
            "${inputs.services-flake}/nix/services/mysql/mysql_test.nix"
            # Fails on macOS with: `error: chmod '"/nix/store/rcx3n94ygmd61rrv2p22sykhk0yx49n4-elasticsearch-7.17.16/modules/x-pack-ml/platform/darwin-aarch64/controller.app"': Operation not permitted`
            # Related: https://github.com/NixOS/nix/issues/6765
            "${inputs.services-flake}/nix/services/elasticsearch_test.nix"
          ]
          # Tests on non-linux host only
          ++ lib.optionals (!pkgs.stdenv.hostPlatform.isLinux) [
            # Fails on Linux due to Nix's build sandbox constraints, see https://github.com/NixOS/nixpkgs/issues/377016#issuecomment-2614610914
            "${inputs.services-flake}/nix/services/mongodb_test.nix"
          ]));
      };
    };
}
