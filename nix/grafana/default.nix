{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  iniFormat = pkgs.formats.ini { };
in
{
  options = {
    description = ''
      Configure grafana.
    '';
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "grafana" { };

    port = lib.mkOption {
      type = types.int;
      description = "Which port to run grafana on.";
      default = 3000;
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Directory where grafana stores its logs and data.";
      default = "./data/${name}";
    };

    extraConf = lib.mkOption {
      type = iniFormat.type;
      description = "Extra configuration for grafana.";
      default = { };
      example = ''
        {
          security.admin_user = "patato";
          security.admin_password = "potato";
        }
      '';
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes."${name}" =
          let
            grafanaConfig =
              {
                server = {
                  protocol = "http";
                  http_port = config.port;
                  domain = "localhost";
                };
              } // config.extraConf;
            grafanaConfigIni = iniFormat.generate "defaults.ini" grafanaConfig;
            startScript = pkgs.writeShellApplication {
              name = "start-grafana";
              runtimeInputs = [ config.package ];
              text = ''
                grafana server --config ${grafanaConfigIni} \
                               --homepath ${config.package}/share/grafana \
                               cfg:paths.data="$(readlink -m ${config.dataDir})"
              '';
            };
          in
          {
            command = startScript;
            readiness_probe = {
              exec.command = "${pkgs.curl}/bin/curl -f ${grafanaConfig.server.protocol}://${grafanaConfig.server.domain}:${builtins.toString grafanaConfig.server.http_port}/api/health";
              initial_delay_seconds = 15;
              period_seconds = 10;
              timeout_seconds = 2;
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
}
