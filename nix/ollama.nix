# Based on https://github.com/shivaraj-bh/ollama-flake/blob/main/services/ollama.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  ollamaPackage = pkgs.ollama.override {
    inherit (config) acceleration;
  };
in
{
  options = {
    enable = lib.mkEnableOption "Enable the Ollama service";
    package = lib.mkOption {
      type = types.package;
      default = ollamaPackage;
      description = "The Ollama package to use";
    };
    port = lib.mkOption {
      type = types.port;
      default = 11434;
      description = "The port on which the Ollama service's REST API will listen";
    };
    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "The host on which the Ollama service's REST API will listen";
    };
    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = ''
        The directory containing the Ollama models.
        Sets the `OLLAMA_MODELS` environment variable.
      '';
    };
    keepAlive = lib.mkOption {
      type = types.str;
      default = "5m";
      description = ''
        The duration that models stay loaded in memory.
        Sets the `OLLAMA_KEEP_ALIVE` environment variable.

        Note: Use a duration string like "5m" for 5 minutes. Or "70" for 70 seconds.
      '';
      example = "70";
    };
    models = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        The models to load post start.
        Search for models of your choice from: https://ollama.com/library
      '';
    };
    acceleration = lib.mkOption {
      type = types.nullOr (types.enum [ false "rocm" "cuda" ]);
      default = null;
      example = "rocm";
      description = ''
        What interface to use for hardware acceleration.

        - `null`: default behavior
          - if `nixpkgs.config.rocmSupport` is enabled, uses `"rocm"`
          - if `nixpkgs.config.cudaSupport` is enabled, uses `"cuda"`
          - otherwise defaults to `false`
        - `false`: disable GPU, only use CPU
        - `"rocm"`: supported by most modern AMD GPUs
        - `"cuda"`: supported by most modern NVIDIA GPUs
      '';
    };
    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        OLLAMA_DEBUG = "1";
      };
      description = ''
        Extra environment variables passed to the `ollama-server` process.
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
              startScript = pkgs.writeShellApplication {
                name = "ollama-server";
                text = ''
                  if [ ! -d "${config.dataDir}" ]; then
                    echo "Creating directory ${config.dataDir}"
                    mkdir -p "${config.dataDir}"
                  fi

                  ${lib.getExe config.package} serve
                '';
              };
            in
            {
              command = startScript;

              environment = {
                OLLAMA_MODELS = config.dataDir;
                OLLAMA_HOST = "${config.host}:${toString config.port}";
                OLLAMA_KEEP_ALIVE = config.keepAlive;
              } // config.environment;

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
              namespace = name;
              availability.restart = "on_failure";
            };

          "${name}-models" = {
            command = pkgs.writeShellApplication {
              name = "ollama-models";
              text = ''
                set -x
                OLLAMA_HOST=${config.host}:${toString config.port}
                export OLLAMA_HOST
                models="${lib.concatStringsSep " " config.models}"
                for model in $models
                do
                  ${lib.getExe config.package} pull "$model"
                done
              '';
            };
            namespace = name;
            depends_on."${name}".condition = "process_healthy";
          };
        };
      };
    };
  };
}
