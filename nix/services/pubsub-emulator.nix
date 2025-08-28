{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    google-cloud-sdk = lib.mkOption {
      type = types.package;
      description = ''
        Which package of google-cloud-sdk to use
        
        Note: google-cloud-sdk used must include the `pubsub-emulator` component
      '';
      default = pkgs.google-cloud-sdk.withExtraComponents [ pkgs.google-cloud-sdk.components.pubsub-emulator ];
      defaultText = lib.literalExpression "pkgs.google-cloud-sdk.withExtraComponents [ pkgs.google-cloud-sdk.components.pubsub-emulator ]";
    };

    jre = lib.mkPackageOption pkgs "jre" { };

    host = lib.mkOption {
      description = "Pubsub Emulator bind address";
      default = "127.0.0.1";
      example = "0.0.0.0";
      type = types.str;
    };

    port = lib.mkOption {
      description = "Pubsub Emulator port to listen on";
      default = 8085;
      type = types.port;
    };

    project = lib.mkOption {
      description = "Pubsub Project Id";
      default = "default";
      type = types.str;
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            {
              command = pkgs.writeShellApplication {
                name = "start-pubsub-emulator";
                runtimeInputs = [ config.google-cloud-sdk config.jre ];
                text = ''
                  mkdir -p "${config.dataDir}"
                  export JAVA_HOME=${config.jre}
                  exec gcloud beta emulators pubsub start --project ${config.project} --data-dir ${config.dataDir} --host-port ${config.host}:${builtins.toString config.port};
                '';
              };
              availability = {
                restart = "on_failure";
                max_restarts = 5;
              };
              readiness_probe = {
                http_get = {
                  host = config.host;
                  port = config.port;
                };
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 2;
                success_threshold = 1;
                failure_threshold = 5;
              };
            };
        };
      };
    };
  };
}
