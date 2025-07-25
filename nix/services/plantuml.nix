{ pkgs
, lib
, name
, config
, ...
}:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "plantuml" { };

    host = lib.mkOption {
      description = "Plantuml bind address (default to null to bind on all interfaces)";
      default = null;
      type = types.nullOr types.str;
    };

    port = lib.mkOption {
      description = "Plantuml port to listen on";
      default = 8080;
      type = types.port;
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" = {
            command =
              let
                commandArgs =
                  "-picoweb:${toString config.port}" + "${if config.host == null then "" else ":" + config.host}";
              in
              "${lib.getExe config.package} ${commandArgs}";
            availability = {
              restart = "on_failure";
              max_restarts = 5;
            };
            readiness_probe = {
              http_get = {
                port = config.port;
              }
              // lib.optionalAttrs (config.host != null) {
                host = config.host;
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
