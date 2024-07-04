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
      type = types.attrsOf (types.submodule {
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
      default = {
        "n1" = { port = 30001; };
        "n2" = { port = 30002; };
        "n3" = { port = 30003; };
        "n4" = { port = 30004; };
        "n5" = { port = 30005; };
        "n6" = { port = 30006; };
      };
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
  };

  config = {
    outputs = {
      settings =
        let
          mkNodeProcess = nodeName: cfg:
            let
              port = builtins.toString cfg.port;
              redisConfig = pkgs.writeText "redis.conf" ''
                port ${port}
                cluster-enabled yes
                cluster-config-file nodes-${port}.conf
                cluster-node-timeout ${builtins.toString config.timeout}
                appendonly yes
                appendfilename "appendonly-${port}.aof"
                dbfilename "dump-${port}.rdb"

                ${lib.optionalString (config.bind != null) "bind ${config.bind}"}
                ${cfg.extraConfig}
              '';

              startScript = pkgs.writeShellApplication {
                name = "start-redis";
                runtimeInputs = [ pkgs.coreutils config.package ];
                text = ''
                  set -euo pipefail

                  export REDISDATA=${config.dataDir}

                  if [[ ! -d "$REDISDATA" ]]; then
                    mkdir -p "$REDISDATA"
                  fi

                  exec redis-server ${redisConfig} --dir "$REDISDATA"
                '';
              };
            in
            lib.nameValuePair "${name}-${nodeName}" {
              command = startScript;
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
          hosts = lib.mapAttrsToList (_: cfg: "${config.bind}:${builtins.toString cfg.port}") config.nodes;
          clusterCreateScript = pkgs.writeShellApplication {
            name = "redis-cluster-create";
            text =
              let
                primaryNodePort = (lib.head (lib.mapAttrsToList lib.nameValuePair config.nodes)).value.port;
              in

              ''
                if ${config.package}/bin/redis-cli --cluster check ${config.bind}:${builtins.toString primaryNodePort}; then
                  echo
                  echo
                  echo "redis-cluster is already created; Skipping initialization"
                else
                  ${config.package}/bin/redis-cli --cluster create ${lib.concatStringsSep " " hosts} --cluster-replicas ${builtins.toString config.replicas} --cluster-yes
                fi
              '';
          };
        in
        {
          processes = (lib.mapAttrs' mkNodeProcess config.nodes) // {
            "${name}-cluster-create" = {
              depends_on = lib.mapAttrs' (nodeName: cfg: lib.nameValuePair "${name}-${nodeName}" { condition = "process_healthy"; }) config.nodes;
              command = lib.getExe clusterCreateScript;
            };
          };
        };
    };
  };
}
