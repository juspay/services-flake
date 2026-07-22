{ pkgs
, config
, lib
, name
, ...
}:

let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkOption {
      type = types.package;
      description = ''
        Which package of RustFS to use,
        e.g. 'inputs.rustfs-flake.packages.''${pkgs.stdenv.hostPlatform.system}.default'.
      '';
    };

    server = {
      host = lib.mkOption {
        type = types.nullOr types.str;
        default = "127.0.0.1";
        description = ''
          The IP interface to bind to.
          `null` means "all interfaces".
        '';
      };

      port = lib.mkOption {
        type = types.port;
        default = 9000;
        description = "The TCP port for the S3 API.";
      };
    };

    console = {
      port = lib.mkOption {
        type = types.port;
        default = 9001;
        description = "The TCP port for the web console.";
      };

      enable = lib.mkOption {
        type = types.bool;
        default = true; # This is the default in RustFS.
        description = "Enable the console.";
      };
    };

    accessKey = lib.mkOption {
      type = types.str;
      default = "rustfsadmin";
      description = "Access key for authentication (5 to 20 characters).";
    };

    secretKey = lib.mkOption {
      type = types.str;
      default = "rustfsadmin";
      description = "Secret key for authentication (8 to 40 characters).";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Log level (error, warn, info, debug, trace).";
    };

    extraEnvironment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Additional environment variables to pass to RustFS.
        See the RustFS documentation for available options
        (e.g. `RUSTFS_CORS_ALLOWED_ORIGINS`, `RUSTFS_TLS_PATH`).
      '';
      example = {
        RUSTFS_OBS_LOGGER_LEVEL = "debug";
        RUSTFS_OBJECT_CACHE_ENABLE = "true";
      };
    };
  };

  config.outputs.settings.processes.${name} = {
    environment = {
      RUST_LOG = config.logLevel;
      RUSTFS_ADDRESS = "${config.server.host}:${lib.toString config.server.port}";
      RUSTFS_CONSOLE_ENABLE = lib.boolToString config.console.enable;
      RUSTFS_CONSOLE_ADDRESS = "${config.server.host}:${lib.toString config.console.port}";

      RUSTFS_ACCESS_KEY = config.accessKey;
      RUSTFS_SECRET_KEY = config.secretKey;

      RUSTFS_DATA_DIR = config.dataDir;
    }
    // config.extraEnvironment;

    command = pkgs.writeShellApplication {
      name = "rustfs";
      text =
        # Bash
        ''
          mkdir -p "$RUSTFS_DATA_DIR"
          exec ${config.package}/bin/rustfs server "$RUSTFS_DATA_DIR"
        '';
    };

    readiness_probe = {
      http_get = {
        host = config.server.host;
        port = config.server.port;
        path = "/health";
      };
      initial_delay_seconds = 1;
      period_seconds = 2;
      timeout_seconds = 2;
      success_threshold = 1;
      failure_threshold = 10;
    };
  };
}
