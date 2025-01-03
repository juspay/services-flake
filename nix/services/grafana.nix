{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  iniFormat = pkgs.formats.ini { };
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    description = ''
      Configure grafana.
    '';
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

    datasources = lib.mkOption {
      type = types.listOf yamlFormat.type;
      description = ''
        List of data sources to configure.

        See https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources for the schema.
      '';
      default = [ ];
      example = ''
        [
          {
            name = "Tempo";
            type = "tempo";
            access = "proxy";
          }
        ]
      '';
    };

    deleteDatasources = lib.mkOption {
      type = types.listOf yamlFormat.type;
      description = "List of data sources to remove.";
      default = [ ];
      example = ''
        [
          { name = "Tempo"; }
        ]
      '';
    };

    declarativePlugins = lib.mkOption {
      type = with types; nullOr (listOf path);
      default = null;
      description = "If non-null, then a list of packages containing Grafana plugins to install. If set, plugins cannot be manually installed.";
      example = "with pkgs.grafanaPlugins; [ grafana-piechart-panel ]";
      # Make sure each plugin is added only once; otherwise building
      # the link farm fails, since the same path is added multiple
      # times.
      apply = x: if lib.isList x then lib.unique x else x;
    };

    providers = lib.mkOption {
      type = types.listOf yamlFormat.type;
      description = ''
        List of dashboard providers to configure.

        See https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards for the schema.
      '';
      default = [ ];
      example = ''
        [
          {
            name = "Databases";
            type = "file";
            options = {
              path = ./dashboards;
              foldersFromFilesStructure = true;
            };
          }
        ]
      '';
    };
  };

  config = {
    outputs = {
      settings = {
        processes."${name}" =
          let
            grafanaConfig = lib.recursiveUpdate
              {
                server = {
                  inherit (config) protocol http_port domain;
                };
              }
              config.extraConf;
            grafanaConfigIni = iniFormat.generate "defaults.ini" grafanaConfig;
            provisioningConfig = pkgs.stdenv.mkDerivation {
              name = "grafana-provisioning";
              datasourcesYaml = yamlFormat.generate "datasources.yaml" {
                apiVersion = 1;
                deleteDatasources = config.deleteDatasources;
                datasources = config.datasources;
              };
              providersYaml = yamlFormat.generate "providers.yaml" {
                apiVersion = 1;
                providers = config.providers;
              };
              buildCommand = ''
                mkdir -p $out
                mkdir -p $out/alerting
                mkdir -p $out/dashboards
                ln -s "$providersYaml" "$out/dashboards/providers.yaml"
                mkdir -p $out/datasources
                ln -s "$datasourcesYaml" "$out/datasources/datasources.yaml"
                mkdir -p $out/notifiers
                mkdir -p $out/plugins
              '';
            };
            declarativePlugins = pkgs.linkFarm "grafana-plugins" (builtins.map (pkg: { name = pkg.pname; path = pkg; }) config.declarativePlugins);
            startScript = pkgs.writeShellApplication {
              name = "start-grafana";
              runtimeInputs =
                [ config.package ] ++
                (lib.lists.optionals pkgs.stdenv.isDarwin [
                  pkgs.coreutils
                ]);
              text = ''
                grafana server --config ${grafanaConfigIni} \
                               --homepath ${config.package}/share/grafana \
                               cfg:paths.data="$(readlink -m ${config.dataDir})" \
                               ${lib.optionalString (config.declarativePlugins != null) "cfg:paths.plugins=${declarativePlugins}"} \
                               cfg:paths.provisioning="${provisioningConfig}"
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

            # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
            availability = {
              restart = "on_failure";
              max_restarts = 5;
            };
          };
      };
    };
  };
}
