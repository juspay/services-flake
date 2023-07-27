{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "redis" { };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The redis-cluster data directory (common for all nodes).";
    };

    nodes = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          port = lib.mkOption {
            type = types.int;
            description = "The TCP port to accept connections. If port is set to `0`, redis will not listen on a TCP socket.";
          };
          extraConfig = lib.mkOption {
            type = types.lines;
            description = "Extra configuration for this node. To be appended to `redis.conf`.";
            default = "";
          };
        };
      });
      default = [
        { port = 30001; }
        { port = 30002; }
        { port = 30003; }
        { port = 30004; }
        { port = 30005; }
        { port = 30006; }
      ];
    };

    bind = lib.mkOption {
      type = types.nullOr types.str;
      default = "127.0.0.1";
      description = ''
        The IP interface to bind to.
        `null` means "all interfaces".

        All the nodes will follow the same bind address.
      '';
      example = "127.0.0.1";
    };

    timeout = lib.mkOption {
      type = types.int;
      default = 2000;
      description = ''
        Time (in milliseconds) after which the node is considered to be down.

        If master node is down, a replica node will take over.
      '';
    };

    replicas = lib.mkOption {
      type = types.int;
      default = 1;
      description = ''
        Number of replicas per Master node.
      '';
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default =
        let
          mkNodeProcess = nodeConfig:
            let
              port = builtins.toString nodeConfig.port;
              redisConfig = pkgs.writeText "redis.conf" ''
                port ${port}
                cluster-enabled yes
                cluster-config-file nodes-${port}.conf
                cluster-node-timeout ${builtins.toString config.timeout}
                appendonly yes
                appendfilename "appendonly-${port}.aof"
                dbfilename "dump-${port}.rdb"

                ${lib.optionalString (config.bind != null) "bind ${config.bind}"}
                ${nodeConfig.extraConfig}
              '';

              startScript = pkgs.writeShellScriptBin "start-redis" ''
                set -euo pipefail

                export REDISDATA=${config.dataDir}

                if [[ ! -d "$REDISDATA" ]]; then
                  mkdir -p "$REDISDATA"
                fi

                exec ${config.package}/bin/redis-server ${redisConfig} --dir "$REDISDATA"
              '';
            in
            {
              "${name}-node-${port}" = {
                command = "${startScript}/bin/start-redis";
                shutdown.command = "${config.package}/bin/redis-cli -p ${port} shutdown nosave";

                readiness_probe = {
                  exec.command = "${config.package}/bin/redis-cli -p ${port} ping";
                  initial_delay_seconds = 2;
                  period_seconds = 10;
                  timeout_seconds = 4;
                  success_threshold = 1;
                  failure_threshold = 5;
                };

                # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
                availability.restart = "on_failure";
              };
            };
          hosts = builtins.map (node: "${config.bind}:${builtins.toString node.port}") config.nodes;
          healthyNodes = builtins.map (node: { "${name}-node-${builtins.toString node.port}".condition = "process_healthy"; }) config.nodes;
          createClusterProcess = {
            "${name}-cluster-create" = {
              depends_on = lib.mkMerge healthyNodes;
              command = "${config.package}/bin/redis-cli --cluster create ${lib.concatStringsSep " " hosts} --cluster-replicas ${builtins.toString config.replicas} --cluster-yes";
            };
          };
          processesList = (builtins.map mkNodeProcess config.nodes) ++ [ createClusterProcess ];
        in
        {
          processes = lib.mkMerge processesList;
        };
    };
  };
}
