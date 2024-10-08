{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
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
  };

  config = {
    outputs = {
      settings = {
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
              };

            };
        };
      };
    };
  };
}
