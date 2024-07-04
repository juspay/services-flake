{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
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

    use_default_settings = lib.mkOption {
      description = "Use default Searxng settings";
      default = true;
      type = types.bool;
    };

    secret_key = lib.mkOption {
      description = "Searxng secret key";
      default = "secret";
      example = "secret-key";
      type = types.str;
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
        doi_resolvers."dummy" = "http://example.org";
        default_doi_resolver = "dummy";
        }
      '';
      description = ''
        Searxng settings
      '';
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" = {
            environment = {
              SEARXNG_SETTINGS_PATH = "${yamlFormat.generate "settings.yaml" (
                lib.recursiveUpdate config.settings {
                  server.bind_address = config.host;
                  server.port = config.port;
                  server.secret_key = config.secret_key;
                  use_default_settings = config.use_default_settings;
                }
              )}";
            };
            command = lib.getExe config.package;
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
