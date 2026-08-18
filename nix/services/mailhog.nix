{
  pkgs,
  lib,
  config,
  name,
  ...
}:

let
  cfg = config;
  types = lib.types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "mailhog" {
      extraDescription = "The mailhog package to use.";
    };

    api = {
      host = lib.mkOption {
        type = types.str;
        description = "Host name for the API.";
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = types.port;
        description = "Port for the API.";
        default = 8025;
      };
    };

    ui = {
      host = lib.mkOption {
        type = types.str;
        description = "Host name for the UI.";
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = types.port;
        description = "Port for the UI.";
        default = 8025;
      };
    };

    smtp = {
      host = lib.mkOption {
        type = types.str;
        description = "Host name for SMTP.";
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = types.port;
        description = "Port for the SMTP.";
        default = 1025;
      };
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "-invite-jim" ];
      description = ''
        Additional arguments passed to `mailhog`.
      '';
    };
  };

  config.outputs.settings.processes.${name} = {
    command =
      pkgs.writeShellScriptBin "mailhog"
        # Bash
        ''
          exec ${lib.getExe cfg.package} \
            -api-bind-addr '${cfg.api.host}:${toString cfg.api.port}' \
            -ui-bind-addr '${cfg.ui.host}:${toString cfg.ui.port}' \
            -smtp-bind-addr '${cfg.smtp.host}:${toString cfg.smtp.port}' \
            ${lib.escapeShellArgs cfg.extraArgs}
        '';

    readiness_probe = {
      http_get = {
        host = cfg.api.host;
        port = cfg.api.port;
        path = "/api/v2/messages";
      };
      initial_delay_seconds = 1;
      period_seconds = 2;
      timeout_seconds = 2;
      success_threshold = 1;
      failure_threshold = 10;
    };
  };
}
