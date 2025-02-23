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
  };

  config = {
    outputs = {
      # systemd and launchd config based on https://github.com/nix-community/home-manager/blob/5031c6d2978109336637977c165f82aa49fa16a7/modules/services/ollama.nix#L78-L108
      # TODO: refactor to reuse between all three outputs and also set sane defaults for `systemd` and `launchd`, just like `defaultProcessSettings`.
      systemd."${name}" = lib.mkIf pkgs.stdenv.isLinux {
        Unit = {
          After = [ "network.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe ollamaPackage} serve";
          Environment =
            (lib.mapAttrsToList (n: v: "${n}=${v}") config.environment)
            ++ [ "OLLAMA_HOST=${config.host}:${toString config.port}" ];
        };
        Install = { WantedBy = [ "default.target" ]; };
      };
      launchd = {
        "${name}" = lib.mkIf pkgs.stdenv.isDarwin {
          config = {
            enable = config.enable;
            config = {
              ProgramArguments = [ (lib.getExe config.package) "serve" ];
              EnvironmentVariables = config.environment // {
                OLLAMA_HOST = "${config.host}:${toString config.port}";
              };
              KeepAlive = {
                Crashed = true;
                SuccessfulExit = false;
              };
              ProcessType = "Background";
            };
          };
        };
      };
      settings = {
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
              availability = {
                restart = "on_failure";
                max_restarts = 5;
              };
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
            depends_on."${name}".condition = "process_healthy";
          };
        };
      };
    };
  };
}
