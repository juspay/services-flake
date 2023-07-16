# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/redis.nix
{ pkgs, lib, options, config, ... }:

with lib;

{
  options.services.redis = lib.mkOption {
    description = ''
      Enable redis server
    '';
    default = { };
    type = with types; attrsOf (submodule ({ name, config, ... }:
      let serviceName = "redis-${name}"; in {
        options = {
          enable = lib.mkEnableOption serviceName;

          package = lib.mkPackageOption pkgs "redis" { };

          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "./data/${serviceName}";
            description = "The redis data directory";
          };

          bind = mkOption {
            type = types.nullOr types.str;
            default = "127.0.0.1";
            description = ''
              The IP interface to bind to.
              `null` means "all interfaces".
            '';
            example = "127.0.0.1";
          };

          port = mkOption {
            type = types.port;
            default = 6379;
            description = ''
              The TCP port to accept connections.

              If port is set to `0`, redis will not listen on a TCP socket.
            '';
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Additional text to be appended to `redis.conf`.";
          };

          output = mkOption {
            type = (options.settings.type.getSubOptions [ ]).processes.type;
            internal = true;
            readOnly = true;
            default = {
              "${serviceName}" =
                let
                  redisConfig = pkgs.writeText "redis.conf" ''
                    port ${toString config.port}
                    ${optionalString (config.bind != null) "bind ${config.bind}"}
                    ${config.extraConfig}
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

                  readiness_probe = {
                    exec.command = "${config.package}/bin/redis-cli -p ${toString config.port} ping";
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
          };
        };
      }));
  };
  config.settings.processes = lib.mkMerge (lib.mapAttrsToList (_: cfg: cfg.output) config.services.redis);
}
