# Based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/open-webui.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    enable = lib.mkEnableOption "Open-WebUI server";
    package = lib.mkPackageOption pkgs "open-webui" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        The host address which the Open-WebUI server HTTP interface listens to.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 1111;
      example = 11111;
      description = ''
        Which port the Open-WebUI server listens to.
      '';
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
      example = ''
        {
          OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
          # Disable authentication
          WEBUI_AUTH = "False";
        }
      '';
      description = "Extra environment variables for Open-WebUI";
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            let
              setupStateDirs = lib.concatMapStrings
                (stateDir:
                  ''
                    if [ ! -d "''$${stateDir}" ]; then
                      mkdir -p "''$${stateDir}"
                    fi

                    ${stateDir}=$(readlink -f "''$${stateDir}")

                    export ${stateDir}
                  '') [ "DATA_DIR" "STATIC_DIR" "HF_HOME" "SENTENCE_TRANSFORMERS_HOME" ];
            in

            {
              environment = {
                DATA_DIR = config.dataDir;
                STATIC_DIR = config.dataDir;
                HF_HOME = config.dataDir;
                SENTENCE_TRANSFORMERS_HOME = config.dataDir;
              } // config.environment;

              command = pkgs.writeShellApplication {
                name = "open-webui-wrapper";
                text = ''
                  ${setupStateDirs}

                  ${lib.getExe config.package} serve --host ${config.host} --port ${builtins.toString config.port}
                '';
              };
              readiness_probe = {
                http_get = {
                  host = config.host;
                  port = config.port;
                };
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
