{
  pkgs,
  lib,
  name,
  config,
  ...
}:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "openobserve" { };

    httpAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The address the HTTP server, which serves both the API and the web UI binds to";
    };

    httpPort = lib.mkOption {
      type = types.port;
      default = 5080;
      description = "The port the HTTP server, which serves both the API and the web UI listens on";
    };

    grpcPort = lib.mkOption {
      type = types.port;
      default = 5081;
      description = "The port the gRPC server listens on";
    };

    extraEnvironment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''
        {
          ZO_ROOT_USER_PASSWORD = "Somethingelse#456";
          ZO_COMPACT_ENABLED = "false";
        }
      '';
      description = ''
        Extra `ZO_*` environment variables for OpenObserve.

        These are merged last, so they override the defaults this module sets,
        including the root user credentials and telemetry.

        See <https://openobserve.ai/docs/environment-variables/> for the full
        list.
      '';
    };
  };

  config.outputs.settings.processes."${name}" = {
    environment = {
      ZO_DATA_DIR = config.dataDir;
      ZO_LOCAL_MODE = "true";
      ZO_TELEMETRY = "false";
      # OpenObserve has no fallback for these and panics on startup without
      # them, so the module supplies working defaults to keep `enable = true`
      # sufficient. Override via `extraEnvironment`.
      ZO_ROOT_USER_EMAIL = "admin@services-flake.com";
      ZO_ROOT_USER_PASSWORD = "Admin1!@";
      ZO_HTTP_ADDR = config.httpAddress;
      ZO_HTTP_PORT = toString config.httpPort;
      ZO_GRPC_PORT = toString config.grpcPort;
    }
    // config.extraEnvironment;

    command = pkgs.writeShellApplication {
      name = "start-openobserve";
      runtimeInputs = [ config.package ];
      text = ''
        mkdir -p ${lib.escapeShellArg config.dataDir}
        exec openobserve
      '';
    };

    readiness_probe = {
      http_get = {
        host = config.httpAddress;
        port = config.httpPort;
        path = "/healthz";
      };
      initial_delay_seconds = 2;
      period_seconds = 5;
      timeout_seconds = 4;
      success_threshold = 1;
      # First boot creates the sqlite schema and its indexes before the HTTP
      # listener accepts connections, so allow more failures than usual.
      failure_threshold = 10;
    };

    availability = {
      restart = "on_failure";
      max_restarts = 5;
    };
  };
}
