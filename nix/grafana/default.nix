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

    http_port = lib.mkOption {
      type = types.int;
      description = "Which port to run grafana on.";
      default = 3000;
    };

    domain = lib.mkOption {
      type = types.str;
      description = "The public facing domain name used to access grafana from a browser.";
      default = "localhost";
    };

    protocol = lib.mkOption {
      type = types.str;
      description = "Protocol (http, https, h2, socket).";
      default = "http";
    };

    root_url = lib.mkOption {
      type = types.str;
      description = "The full public facing url.";
      default = "${config.protocol}://${config.domain}:${builtins.toString config.http_port}";
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
            grafanaConfig = lib.recursiveUpdate
              config.extraConf
              {
                server = {
                  inherit (config) protocol http_port domain root_url;
                };
              };
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
              http_get = {
                host = config.domain;
                scheme = config.protocol;
                port = config.http_port;
                path = "/api/health";
              };
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
