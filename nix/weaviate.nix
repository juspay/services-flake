{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  asAtom = value:
    if builtins.isList value then lib.concatStringsSep "," value else value;
  toStr = value:
    if builtins.isString value then value else builtins.toJSON value;
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "weaviate" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
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

    environment = lib.mkOption {
      type = types.attrsOf (types.oneOf [ types.raw (types.listOf types.str) ]);
      default = { };
      description = ''
        Weaviate environment variables.

        See https://weaviate.io/developers/weaviate/config-refs/env-vars
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
      apply = lib.mapAttrs (_: value: toStr (asAtom value));
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            let
              startScript = pkgs.writeShellApplication {
                name = "start-weaviate";
                runtimeInputs = [ config.package ];
                text = ''
                  exec weaviate --scheme http --host ${config.host} --port ${toString config.port}
                '';
              };
            in
            {
              environment = config.environment // { "PERSISTENCE_DATA_PATH" = config.dataDir; };

              command = startScript;

              readiness_probe = {
                http_get = {
                  inherit (config) host port;
                  path = "/v1/.well-known/ready";
                };
                initial_delay_seconds = 3;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };

              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
