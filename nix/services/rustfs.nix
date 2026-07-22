{ pkgs
, config
, lib
, name
, ...
}:

let
  inherit (lib) types mkOption mkEnableOption;
in
{
  options = {
    package = mkOption {
      type = types.package;
      description = ''
        Which package of RustFS to use,
        e.g. 'inputs.rustfs-flake.packages.''${pkgs.stdenv.hostPlatform.system}.default'.
      '';
    };

    server = {
      host = mkOption {
        type = types.nullOr types.str;
        default = "127.0.0.1";
        description = ''
          The IP interface to bind to.
          `null` means "all interfaces".
        '';
      };

      port = mkOption {
        type = types.port;
        default = 9000;
        description = "The TCP port for the S3 API.";
      };
    };

    console = {
      port = mkOption {
        type = types.port;
        default = 9001;
        description = "The TCP port for the web console.";
      };

      enable = mkOption {
        type = types.bool;
        default = true; # This is the default in RustFS.
        description = "Enable the console.";
      };
    };

    accessKey = mkOption {
      type = types.str;
      default = "rustfsadmin";
      description = "Access key for authentication (5 to 20 characters).";
    };

    secretKey = mkOption {
      type = types.str;
      default = "rustfsadmin";
      description = "Secret key for authentication (8 to 40 characters).";
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      description = "Log level (error, warn, info, debug, trace).";
    };

    region = mkOption {
      type = types.str;
      default = "us-east-1";
      description = "The service region reported to clients.";
    };

    provision = {
      enable = mkEnableOption "rustfs provisioning (buckets + IAM blueprint) on startup";

      buckets = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Buckets to create on startup (idempotent).";
        example = [
          "uploads"
          "assets"
        ];
      };

      iam = {
        path = lib.mkOption {
          type = types.nullOr (
            types.either
              (types.pathWith {
                inStore = false;
                absolute = false;
              })
              # A nix store path.
              (types.pathWith { inStore = true; })
          );
          default = null;
          description = ''
            Path to the folder from RustFS IAM export (unzipped) to restore via the admin `import-iam` endpoint on startup.
            Produce it via the console IAM export tab.
            Import is get-or-create, so it is safe to re-apply on an already-populated data dir.
          '';
        };
      };

      extraScript = lib.mkOption {
        type = types.nullOr types.package;
        default = null;
        description = ''
          Extra script with custom provisioning steps.
        '';
      };
    };

    extraEnvironment = mkOption {
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

      RUSTFS_REGION = config.region;
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

  config.outputs.settings.processes."${name}-provision" = lib.mkIf config.provision.enable {
    command = pkgs.writeShellApplication {
      name = "rustfs-provision";
      runtimeInputs = [
        pkgs.curl
        pkgs.minio-client
        pkgs.zip
      ];
      text =
        # Bash
        ''
          endpoint="${config.server.host}:${lib.toString config.server.port}"

          # Throwaway --config-dir so nothing is written to $HOME.
          tmp="$(mktemp -d)"
          trap 'rm -rf "$tmp"' EXIT

          export MC_HOST_rustfs="http://${config.accessKey}:${config.secretKey}@$endpoint"
        ''
        + lib.concatStringsSep "\n" (
          lib.map
            (
              b:
              # Bash
              ''
                echo "Provision: Ensuring bucket 'rustfs/${b}'."
                mc --config-dir "$tmp" --ignore-existing "rustfs/${b}"
              ''
            )
            config.provision.buckets
        )
        + (lib.optionalString (config.provision.iam.path != null) ''
          echo "Provision: Importing IAM from zipping '${config.provision.iam.path}'"

          endpoint="http://${config.server.host}:${lib.toString config.server.port}"
          zip -rq "$tmp/iam.zip" "${config.provision.iam.path}"

          curl -fsS -X PUT \
            --aws-sigv4 "aws:amz:${config.region}:s3" \
            -u "${config.accessKey}:${config.secretKey}" \
            --data-binary "@$tmp/iam.zip" \
            -H "Content-Type: application/zip" \
            "http://$endpoint/rustfs/admin/v3/import-iam"

          echo "Provision: IAM import done."
        '')
        + (lib.optionalString
          (
            config.provision.extraScript != null
          ) "${lib.getExe config.provision.extraScript}")
        + ''
          echo "Provision: Done."
        '';
    };

    depends_on.${name}.condition = "process_healthy";
    availability.restart = "no";
  };
}
