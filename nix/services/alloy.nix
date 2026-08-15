{
  pkgs,
  lib,
  name,
  config,
  ...
}:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "grafana-alloy" { };

    configFile = lib.mkOption {
      type = types.path;
      example = lib.literalExpression "./config.alloy";
      description = ''
        Path to an Alloy configuration file (Alloy's River-like language).

        Required: Alloy will not start without a config. Point this at your own
        `.alloy` file to define pipelines.

        See <https://grafana.com/docs/alloy/latest/configure/> for the config
        language.
      '';
    };

    listenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the Alloy HTTP server (UI and API) binds to";
    };

    port = lib.mkOption {
      type = types.port;
      default = 12345;
      description = "Port the Alloy HTTP server (UI and API) listens on";
    };

    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''[ "--stability.level=experimental" ]'';
      description = "Extra flags passed to `alloy run`";
    };
  };

  config.outputs.settings.processes."${name}" = {
    command = pkgs.writeShellApplication {
      name = "start-alloy";
      runtimeInputs = [ config.package ];
      text = ''
        mkdir -p ${lib.escapeShellArg config.dataDir}
        exec alloy run ${lib.escapeShellArg (toString config.configFile)} \
          --server.http.listen-addr=${config.listenAddress}:${toString config.port} \
          --storage.path=${lib.escapeShellArg config.dataDir} \
          ${lib.escapeShellArgs config.extraFlags}
      '';
    };

    readiness_probe = {
      http_get = {
        host = config.listenAddress;
        port = config.port;
        path = "/-/ready";
      };
      initial_delay_seconds = 2;
      period_seconds = 10;
      timeout_seconds = 4;
      success_threshold = 1;
      failure_threshold = 5;
    };

    availability = {
      restart = "on_failure";
      max_restarts = 5;
    };
  };
}
