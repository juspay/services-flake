{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  format = pkgs.formats.json { };
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "weaviate" { };

    host = lib.mkOption {
      type = types.nullOr types.str;
      default = "0.0.0.0";
      description = ''
        The IP to listen on
      '';
      example = "0.0.0.0";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8080;
      description = ''
        The port to listen on for connections
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        Weaviate configuration.
      '';
      example = lib.literalExpression ''
        {
          "authentication": {
            "anonymous_access": {
              "enabled": true
            }
          },
          "authorization": {
            "admin_list": {
              "enabled": false
            }
          },
          "query_defaults": {
            "limit": 100
          },
          "persistence": {
            "dataPath": "./data"
          }
        }
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
              configFile = format.generate "weaviate.conf.json" config.settings;

              startScript = pkgs.writeShellApplication {
                name = "start-weaviate";
                runtimeInputs = [ config.package ];
                text = ''
                  exec weaviate --scheme http --host ${config.host} --port ${toString config.port} --config-file ${configFile}
                '';
              };

              readyScript = pkgs.writeText "ready.py" ''
                import weaviate
                client = weaviate.connect_to_local(port=${toString config.port}, host="${config.host}")
                client.close()
              '';
            in
            {
              command = startScript;

              readiness_probe = {
                exec.command = "${(pkgs.python3.withPackages (p: [ p.weaviate-client ]))}/bin/python ${readyScript}";
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
