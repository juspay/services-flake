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

    enableOcr = lib.mkOption {
      default = true;
      description = ''
        Whether to enable OCR support by adding the `tesseract` package as a dependency.
      '';
      type = types.bool;
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
          "${name}" =
            let
              tikaPackage = config.package.override {
                inherit (config) enableOcr;
              };
            in
            {
              command = "${lib.getExe tikaPackage} --host ${config.host} --port ${toString config.port} ${lib.optionalString (config.configFile != null) "--config ${config.configFile}"}";
              availability = {
                restart = "on_failure";
                max_restarts = 5;
              };
              readiness_probe = {
                http_get = {
                  host = config.host;
                  port = config.port;
                };
              };
            };
        };
      };
    };
  };
}
