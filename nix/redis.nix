# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/redis.nix
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
      description = "The redis data directory";
    };

    bind = lib.mkOption {
      type = types.nullOr types.str;
      default = "127.0.0.1";
      description = ''
        The IP interface to bind to.
        `null` means "all interfaces".
      '';
      example = "127.0.0.1";
    };

    port = lib.mkOption {
      type = types.port;
      default = 6379;
      description = ''
        The TCP port to accept connections.

        If port is set to `0`, redis will not listen on a TCP socket.
      '';
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Additional text to be appended to `redis.conf`.";
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}" =
            let
              redisConfig = pkgs.writeText "redis.conf" ''
                port ${toString config.port}
                ${lib.optionalString (config.bind != null) "bind ${config.bind}"}
                ${config.extraConfig}
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
            {
              command = startScript;

              readiness_probe = {
                exec.command = "${config.package}/bin/redis-cli -p ${toString config.port} ping";
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };
              namespace = name;

              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
