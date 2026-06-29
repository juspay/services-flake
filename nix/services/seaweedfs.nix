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
    package = lib.mkPackageOption pkgs "seaweedfs" { };
    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        IP or hostname the SeaweedFS server binds to and advertises as.
      '';
    };
    master = {
      port = lib.mkOption {
        type = types.port;
        default = 9333;
        description = "HTTP port for the master server.";
      };
      grpcPort = lib.mkOption {
        type = types.nullOr types.port;
        default = null;
        description = ''
          gRPC port for the master server. If null, defaults to `master.port + 10000`.
        '';
      };
      defaultReplication = lib.mkOption {
        type = types.str;
        default = "000";
        description = ''
          Default replication policy. `000` disables replication
        '';
      };
      volumeSizeLimitMB = lib.mkOption {
        type = types.ints.positive;
        default = 1024;
        description = "Master stops directing writes to volumes larger than this.";
      };
    };
    volume = {
      port = lib.mkOption {
        type = types.port;
        default = 8080;
        description = "HTTP port for the volume server.";
      };
      grpcPort = lib.mkOption {
        type = types.nullOr types.port;
        default = null;
        description = ''
          gRPC port for the volume server. If null, defaults to `volume.port + 10000`.
        '';
      };
      max = lib.mkOption {
        type = types.str;
        default = "8";
        description = ''
          Maximum number of volumes for the volume server.
        '';
      };
    };
    filer = {
      enable = lib.mkEnableOption "the SeaweedFS filer server";
      port = lib.mkOption {
        type = types.port;
        default = 8888;
        description = "HTTP port for the filer server.";
      };
      grpcPort = lib.mkOption {
        type = types.nullOr types.port;
        default = null;
        description = ''
          gRPC port for the filer server. If null, defaults to `filer.port + 10000`.
        '';
      };
    };
    s3 = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the S3 gateway.";
        apply =
          v:
          lib.throwIf
            (
              v && !config.filer.enable
            ) "services.seaweedfs.${name}.filer.enable must be true when s3.enable is true"
            v;
      };
      port = lib.mkOption {
        type = types.port;
        default = 8333;
        description = "HTTP port for the S3 API.";
      };
      config = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to an S3 config file (identities/credentials). When null, the S3
          gateway runs without authentication.
        '';
      };
    };
    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra arguments to pass to `weed server`.";
    };
  };

  config.outputs.settings.processes."${name}" = {
    command = pkgs.writeShellApplication {
      name = "start-seaweedfs";
      runtimeInputs = [ config.package ];
      text = ''
        mkdir -p ${lib.escapeShellArg "${config.dataDir}/master"} \
          ${lib.escapeShellArg "${config.dataDir}/volume"} \
          ${lib.optionalString config.filer.enable (lib.escapeShellArg "${config.dataDir}/filer")}
        ${lib.getExe config.package} server ${
          lib.escapeShellArgs (
            [
              "-ip=${config.host}"
              "-ip.bind=${config.host}"
              "-dir=${config.dataDir}/volume"
              "-master.dir=${config.dataDir}/master"
              "-master.port=${toString config.master.port}"
              "-master.defaultReplication=${config.master.defaultReplication}"
              "-master.volumeSizeLimitMB=${toString config.master.volumeSizeLimitMB}"
              "-volume.port=${toString config.volume.port}"
              "-volume.max=${config.volume.max}"
            ]
            ++ lib.optional (
              config.master.grpcPort != null
            ) "-master.port.grpc=${toString config.master.grpcPort}"
            ++ lib.optional (
              config.volume.grpcPort != null
            ) "-volume.port.grpc=${toString config.volume.grpcPort}"
            ++ lib.optionals config.filer.enable [
              "-filer"
              "-filer.port=${toString config.filer.port}"
            ]
            ++ lib.optional (
              config.filer.enable && config.filer.grpcPort != null
            ) "-filer.port.grpc=${toString config.filer.grpcPort}"
            ++ lib.optionals config.s3.enable [
              "-s3"
              "-s3.port=${toString config.s3.port}"
            ]
            ++ lib.optional (config.s3.enable && config.s3.config != null) "-s3.config=${config.s3.config}"
            ++ config.extraArgs
          )
        }
      '';
    };

    readiness_probe = {
      exec.command =
        let
          check = url: "${lib.getExe pkgs.curl} -fsS -o /dev/null ${lib.escapeShellArg url}";
        in
        # Below generates curl checks for all endpoints separated by &&
        lib.concatStringsSep " && " (
          [
            (check "http://${config.host}:${toString config.master.port}/cluster/healthz")
            (check "http://${config.host}:${toString config.volume.port}/healthz")
          ]
          ++ lib.optional config.filer.enable (check "http://${config.host}:${toString config.filer.port}/healthz")
          ++ lib.optional config.s3.enable (check "http://${config.host}:${toString config.s3.port}/healthz")
        );
      initial_delay_seconds = 2;
      period_seconds = 10;
      timeout_seconds = 4;
      success_threshold = 1;
      failure_threshold = 5;
    };

    availability = {
      restart = "on_failure";
      max_restarts = 5;
    };
  };
}
