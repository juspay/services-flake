# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/redis.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "redis" { };

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
  };

  config = {
    outputs = {
      settings = {
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
              };
            };
        };
      };
    };
  };
}
