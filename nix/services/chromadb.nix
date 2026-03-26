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
    package = lib.mkPackageOption pkgs [ "python3Packages" "chromadb" ] { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The IP to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 8000;
      description = ''
        The port to listen on for connections.
      '';
    };
  };

  config.outputs.settings.processes."${name}" =
    let
      startScript = pkgs.writeShellApplication {
        name = "start-chromadb";
        runtimeInputs = [ config.package ];
        text = ''
          mkdir -p ${lib.escapeShellArg config.dataDir}
          exec chroma run \
            --path ${lib.escapeShellArg config.dataDir} \
            --host "${config.host}" \
            --port ${toString config.port}
        '';
      };
    in
    {
      command = startScript;

      readiness_probe = {
        http_get = {
          host = config.host;
          port = config.port;
          path = "/api/v2/heartbeat";
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
