{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types literalExpression;
in
{
  options = {
    package = lib.mkPackageOption pkgs "tika" { };

    host = lib.mkOption {
      description = "Apache Tika bind address";
      default = "127.0.0.1";
      example = "0.0.0.0";
      type = types.str;
    };

    port = lib.mkOption {
      description = "Apache Tika port to listen on";
      default = 9998;
      type = types.port;
    };

    configFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        The Apache Tika configuration (XML) file to use.
      '';
      example = literalExpression "./tika/tika-config.xml";
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" = {
            command = "${lib.getExe config.package} --host ${config.host} --port ${toString config.port} ${lib.optionalString (config.configFile != null) "--config ${config.configFile}"}";
            availability.restart = "on_failure";
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
          };
        };
      };
    };
  };
}
