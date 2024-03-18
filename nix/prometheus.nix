{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "prometheus" { };

    port = lib.mkOption {
      type = types.port;
      default = 9090;
      description = "Port to listen on";
    };

    listenAddress = lib.mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = lib.mdDoc "Address to listen on for the web interface, API, and telemetry";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The prometheus data directory";
    };

    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra commandline options when launching Prometheus";
    };

    defaultExtraConfig = lib.mkOption {
      type = yamlFormat.type;
      internal = true;
      readOnly = true;
      default = {
        global = {
          scrape_interval = "15s";
          evaluation_interval = "15s";
        };
      };
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = "Additional config for prometheus";
      example = ''
        # scrape prometheus itself
        scrape_configs = [{
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:9090" ];
          }];
        }];
      '';
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}" =
            let
              prometheusConfig = yamlFormat.generate "prometheus.yaml" (
                lib.recursiveUpdate config.defaultExtraConfig config.extraConfig
              );
              execFlags = builtins.concatStringsSep " \\\n" ([
                "--config.file=${prometheusConfig}"
                "--storage.tsdb.path=${config.dataDir}"
                "--web.listen-address=${config.listenAddress}:${builtins.toString config.port}"
              ] ++ config.extraFlags);

              startScript = pkgs.writeShellApplication {
                name = "start-prometheus";
                runtimeInputs = [ config.package ];
                text = "prometheus ${execFlags}";
              };
            in
            {
              command = startScript;
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
              namespace = name;

              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
