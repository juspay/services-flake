{ pkgs
, lib
, name
, config
, ...
}:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };

  settingType =
    with types;
    (oneOf [
      bool
      int
      float
      str
      (listOf settingType)
      (attrsOf settingType)
    ])
    // {
      description = "JSON value";
    };
in
{
  options = {
    enable = lib.mkEnableOption name;
    package = lib.mkPackageOption pkgs "searxng" { };

    host = lib.mkOption {
      description = "Searxng bind address";
      default = "127.0.0.1";
      type = types.str;
    };

    port = lib.mkOption {
      description = "Searxng port to listen on";
      default = 8080;
      type = types.port;
    };

    settings = lib.mkOption {
      types = yamlFormat.type;
      default = {
        server.secret_key = "secret";
        server.limiter = false;
      };
      example = lib.literalExpression ''
        {
          server.secret_key = "secret";
          server.limiter = false;
        }
      '';
      description = ''
        Searxng settings. These will be merged with (taking precedence over)
        the default configuration.
      '';
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}" = {
            environment = {
              SEARXNG_SETTINGS_PATH = "${pkgs.writeText "settings.yml" (
                builtins.toJSON (
                  lib.recursiveUpdate config.settings {
                    use_default_settings = true;
                    server.bind_address = config.host;
                    server.port = config.port;
                  }
                )
              )}";
            };
            command = lib.getExe config.package;
            namespace = name;
            availability.restart = "on_failure";
            readiness_probe = {
              exec.command = "${lib.getExe pkgs.curl} -f -k http://${config.host}:${toString config.port}";
              initial_delay_seconds = 5;
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
