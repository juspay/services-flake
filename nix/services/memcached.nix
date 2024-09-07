# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/memcached.nix
{ pkgs
, lib
, name
, config
, ...
}:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "memcached" { };

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
      default = 11211;
      description = ''
        The TCP port to accept connections.

        If port 0 is specified memcached will not listen on a TCP socket.
      '';
    };

    startArgs = lib.mkOption {
      type = types.listOf types.lines;
      default = [ ];
      example = [ "--memory-limit=100M" ];
      description = ''
        Additional arguments passed to `memcached` during startup.
      '';
    };
  };

  config = {
    outputs.settings.processes.${name} = {
      command = "${config.package}/bin/memcached --port=${toString config.port} --listen=${config.bind} ${lib.concatStringsSep " " config.startArgs}";

      readiness_probe = {
        exec.command = ''
          echo -e "stats\nquit" | ${pkgs.netcat}/bin/nc ${config.bind} ${toString config.port} > /dev/null 2>&1
        '';
        initial_delay_seconds = 2;
        period_seconds = 10;
        timeout_seconds = 4;
        success_threshold = 1;
        failure_threshold = 5;
      };

      # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
      availability = {
        restart = "on_failure";
        max_restarts = 5;
      };
    };
  };
}
