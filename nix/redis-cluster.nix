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

    port = lib.mkOption {
      type = types.port;
      default = 30001;
      description = ''
        The TCP port to accept connections.

        Next node will use the next port and so on.

        If port is set to `0`, redis will not listen on a TCP socket.
      '';
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

    nodes = lib.mkOption {
      type = types.int;
      default = 6;
      description = ''
        Number of nodes in the cluster.
      '';
    };

    replicas = lib.mkOption {
      type = types.int;
      default = 1;
      description = ''
        Number of replicas per Master node.
      '';
    };

    extraConfigs = lib.mkOption {
      type = types.attrsOf types.lines;
      default = { };
      description = "Attrset map of node (identified by port number) to the respective `redis.conf`.";
      example = ''
        {
          {
            30001 = "port 30001";
          };
        }
      '';
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default =
        let
          hosts = lib.genList (x: "${config.bind}:${builtins.toString(config.port + x)}") config.nodes;
          ports = lib.genList (x: "${builtins.toString(config.port + x)}") config.nodes;
          healthyNodes = lib.genAttrs ports (port: { condition = "process_healthy"; });
          node = port:
            let
              redisConfig = pkgs.writeText "redis.conf" ''
                port ${port}
                cluster-enabled yes
                cluster-config-file nodes-${port}.conf
                cluster-node-timeout ${builtins.toString config.timeout}
                appendonly yes
                appendfilename "appendonly-${port}.aof"
                dbfilename "dump-${port}.rdb"

                ${lib.optionalString (config.bind != null) "bind ${config.bind}"}
                ${lib.optionalString (builtins.hasAttr port config.extraConfigs) "${config.extraConfigs.${port}}"}
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
        in
        {
          processes = lib.genAttrs ports (port: node port) //
            {
              "cluster-create" = {

                depends_on = healthyNodes;
                command = "${config.package}/bin/redis-cli --cluster create ${lib.concatStringsSep " " hosts} --cluster-replicas ${builtins.toString config.replicas} --cluster-yes";
              };
            };
        };
    };
  };
}
