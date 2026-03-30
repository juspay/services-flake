{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  settingsFormat = pkgs.formats.yaml { };

  defaultSettings = {
    storage = {
      storage_path = "${config.dataDir}/storage";
      snapshots_path = "${config.dataDir}/snapshots";
      on_disk_payload = true;
    };
    service = {
      host = config.host;
      http_port = config.httpPort;
      grpc_port = config.grpcPort;
      enable_cors = true;
    };
    telemetry_disabled = true;
  };

  finalSettings = lib.recursiveUpdate defaultSettings config.settings;
  configFile = settingsFormat.generate "config.yaml" finalSettings;
in
{
  options = {
    package = lib.mkPackageOption pkgs "qdrant" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The IP to listen on.
      '';
    };

    httpPort = lib.mkOption {
      type = types.port;
      default = 6333;
      description = ''
        The HTTP port for the REST API.
      '';
    };

    grpcPort = lib.mkOption {
      type = types.port;
      default = 6334;
      description = ''
        The gRPC port.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Additional Qdrant configuration in YAML format.
        Merged with default settings via recursive update.

        See https://github.com/qdrant/qdrant/blob/master/config/config.yaml
      '';
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Extra command-line arguments to pass to qdrant.
      '';
    };
  };

  config.outputs.settings.processes."${name}" =
    let
      startScript = pkgs.writeShellApplication {
        name = "start-qdrant";
        runtimeInputs = [ config.package ];
        text = ''
          mkdir -p ${lib.escapeShellArg "${config.dataDir}/storage"} ${lib.escapeShellArg "${config.dataDir}/snapshots"}
          exec qdrant --config-path "${configFile}" \
            ${lib.escapeShellArgs config.extraArgs}
        '';
      };
    in
    {
      command = startScript;

      readiness_probe = {
        http_get = {
          host = config.host;
          port = config.httpPort;
          path = "/healthz";
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
