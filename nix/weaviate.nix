{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "weaviate" { };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data";
      description = "Path to the Weaviate data store";
    };

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

    envs = lib.mkOption {
      type = types.attrsOf (types.oneOf [ types.str types.int types.bool (types.listOf types.str) ]);
      default = { };
      description = ''
        Weaviate environment variables.
      '';
      example = lib.literalExpression ''
        {
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED = true;
          QUERY_DEFAULTS_LIMIT = 100;
          DISABLE_TELEMETRY = true;
          LIMIT_RESOURCES = true;
          ENABLE_MODULES = ["text2vec-openai" "generative-openai"];
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
              toStr = value:
                if builtins.isString value then builtins.toJSON value
                else if builtins.isBool value then (if value then "true" else "false")
                else if builtins.isList value then builtins.toJSON (lib.concatStringsSep "," value)
                else if builtins.isInt value then toString value
                else throw "Unrecognized type";

              exports = (lib.mapAttrsToList (name: value: "export ${name}=${toStr value}") ({ "PERSISTENCE_DATA_PATH" = config.dataDir; }
                // config.envs));

              startScript = pkgs.writeShellApplication {
                name = "start-weaviate";
                runtimeInputs = [ config.package ];
                text = ''
                  ${lib.concatStringsSep "\n" exports}
                  exec weaviate --scheme http --host ${config.host} --port ${toString config.port}
                '';
              };
            in
            {
              command = startScript;

              readiness_probe = {
                http_get = {
                  host = config.host;
                  port = config.port;
                  path = "/v1/.well-known/ready";
                };
                initial_delay_seconds = 3;
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
