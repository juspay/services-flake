{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkOption {
      type = types.package;
      description = "Which package of google-cloud-sdk to use";
      default = pkgs.google-cloud-sdk;
      defaultText = lib.literalExpression "pkgs.google-cloud-sdk";
      apply = gcloudPkg:
        if builtins.hasAttr "withExtraComponents" gcloudPkg
        then
          (
            if builtins.hasAttr "components" gcloudPkg
            then
              (
                if builtins.hasAttr "pubsub-emulator" gcloudPkg.components
                then gcloudPkg.withExtraComponents [ gcloudPkg.components.pubsub-emulator ]
                else
                  builtins.throw ''
                    pubsub-emulator component is missing from google-cloud-sdk package.
                    `services.google-cloud-sdk.package.components` is missing the `pubsub-emulator` attribute.
                  ''
              )
            else
              builtins.throw ''
                Cannot add pubsub emulator component to the google-cloud-sdk package.
                `services.google-cloud-sdk.package` is missing the `components` attribute.
              ''
          )
        else
          builtins.throw ''
            Cannot add pubsub emulator component to the google-cloud-sdk package.
            `services.google-cloud-sdk.package` is missing the `withExtraComponents` attribute.
          '';
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
                runtimeInputs = [ config.package config.jre ];
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
