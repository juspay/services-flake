# Based on https://github.com/cachix/devenv/blob/b6b5b96bd0b669b1f41147cbde950c26085a25c8/src/modules/services/minio.nix
{ pkgs, lib, config, name, ... }:
let
  types = lib.types;

  MINIO_DATA_DIR = config.dataDir + "/data";
  MINIO_CONFIG_DIR = config.dataDir + "/config";

  setupScript = pkgs.writeShellApplication {
    name = "setup-minio";
    text = ''
      export MINIO_DATA_DIR="${MINIO_DATA_DIR}"
      export MINIO_CONFIG_DIR="${MINIO_CONFIG_DIR}"
      mkdir -p "$MINIO_DATA_DIR" "$MINIO_CONFIG_DIR"
      ${lib.concatMapStringsSep "\n" (bucket: ''
        mkdir -p "$MINIO_DATA_DIR/${lib.escapeShellArg bucket}"
      '') config.buckets}
    '';
  };

  startScript = pkgs.writeShellApplication {
    name = "start-minio";
    text = ''
      export MINIO_DATA_DIR="${MINIO_DATA_DIR}"
      export MINIO_CONFIG_DIR="${MINIO_CONFIG_DIR}"
      export MINIO_REGION="${config.region}"
      export MINIO_BROWSER="${if config.browser then "on" else "off"}"
      export MINIO_ROOT_USER="${config.accessKey}"
      export MINIO_ROOT_PASSWORD="${config.secretKey}"
      exec ${serverCommand}
    '';
  };

  serverCommand = lib.escapeShellArgs [
    (lib.getExe config.package)
    "server"
    "--json"
    "--address"
    "${config.host}:${toString config.port}"
    "--console-address"
    config.consoleAddress
    "--config-dir=${MINIO_CONFIG_DIR}"
    MINIO_DATA_DIR
  ];
in
{
  options = {
    host = lib.mkOption {
      default = "127.0.0.1";
      type = types.str;
      description = "Host for minio to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 9000;
      description = "Port for minio to listen on.";
    };

    consoleAddress = lib.mkOption {
      default = "127.0.0.1:9001";
      type = types.str;
      description = "IP address and port of the web UI (console).";
    };

    accessKey = lib.mkOption {
      default = "minioadmin";
      type = types.str;
      description = ''
        Access key of 5 to 20 characters in length that clients use to access the server.
      '';
    };

    secretKey = lib.mkOption {
      default = "minioadmin";
      type = types.str;
      description = ''
        Specify the Secret key of 8 to 40 characters in length that clients use to access the server.
      '';
    };

    region = lib.mkOption {
      default = "us-east-1";
      type = types.str;
      description = ''
        The physical location of the server. By default it is set to us-east-1, which is same as AWS S3's and MinIO's default region.
      '';
    };

    browser = lib.mkOption {
      default = true;
      type = types.bool;
      description = "Enable or disable access to web UI.";
    };

    package = lib.mkPackageOption pkgs "minio" { };

    buckets = lib.mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "List of buckets to ensure exist on startup.";
    };
  };
  config.outputs.settings.processes = {
    "${name}-init" = {
      command = setupScript;
    };
    "${name}" = {
      command = startScript;
      readiness_probe = {
        http_get = {
          host = config.host;
          port = config.port;
          path = "/minio/health/live";
        };
        initial_delay_seconds = 2;
        period_seconds = 10;
        timeout_seconds = 4;
        success_threshold = 1;
        failure_threshold = 5;
      };
      depends_on."${name}-init".condition = "process_completed_successfully";
      # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
      availability = {
        restart = "on_failure";
        max_restarts = 5;
      };
    };
  };
}
