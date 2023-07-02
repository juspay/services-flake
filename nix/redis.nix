# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/redis.nix
{ pkgs, lib, config, ... }:

with lib;

{
  options.services.redis = lib.mkOption {
    description = ''
      Enable redis server
    '';
    default = { };
    type = lib.types.submodule ({ config, ... }: {
      options = {
        enable = lib.mkEnableOption "redis";

        name = lib.mkOption {
          type = lib.types.str;
          default = "redis";
          description = "Unique process name";
        };

        package = lib.mkPackageOption pkgs "redis" { };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "./data/${config.name}";
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
            If port 0 is specified Redis, will not listen on a TCP socket.
          '';
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Additional text to be appended to `redis.conf`.";
        };
      };
    });

  };

  config = let cfg = config.services.redis; in lib.mkIf cfg.enable {

    settings.processes.${cfg.name} = 
    let
      redisConfig = pkgs.writeText "redis.conf" ''
        port ${toString cfg.port}
        ${optionalString (cfg.bind != null) "bind ${cfg.bind}"}
        ${cfg.extraConfig}
      '';

      startScript = pkgs.writeShellScriptBin "start-redis" ''
        set -euo pipefail

        export REDISDATA=${cfg.dataDir}


        if [[ ! -d "$REDISDATA" ]]; then
          mkdir -p "$REDISDATA"
        fi

        exec ${cfg.package}/bin/redis-server ${redisConfig} --dir "$REDISDATA"
      '';
    in
    {
      command = "${startScript}/bin/start-redis";

      readiness_probe = {
        exec.command = "${cfg.package}/bin/redis-cli -p ${toString cfg.port} ping";
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
}
