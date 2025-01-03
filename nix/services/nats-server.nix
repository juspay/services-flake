{ pkgs
, lib
, name
, config
, ...
}:
let
  settingsFormat = pkgs.formats.json { };
  configFile = settingsFormat.generate "nats.conf" config.settings;
  validateConfig =
    file:
    pkgs.runCommand "validated-nats.conf" { nativeBuildInputs = [ config.package ]; } ''
      nats-server --config "${file}" -t
      ln -s "${file}" "$out"
    '';
in
{
  options = {
    package = lib.mkPackageOption pkgs "nats-server" { };
    settings = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options = {
          server_name = lib.mkOption {
            default = name;
            example = "n1-c3";
            type = lib.types.str;
            description = ''
              Name of the NATS server, must be unique if clustered.
            '';
          };
          port = lib.mkOption {
            default = 4222;
            type = lib.types.port;
            description = ''
              Port on which to listen.
            '';
          };
          monitor_port = lib.mkOption {
            default = 8222;
            type = lib.types.port;
            description = ''
              HTTP monitoring port.
            '';
          };
        };
      };
      example = lib.literalExpression ''
        {
          port = 14222;
          monitor_port = 18222;
          accounts = {
            "$SYS" = {
              users = [
                { user = "admin"; pass = "admin"; }
              ];
            };
            js = {
              jetstream = "enabled";
              users = [
                { user = "js"; pass = "js"; }
              ];
            };
          };
          cluster = {
            name = "cluster";
            port = 14248;
            routes = [
              "nats://localhost:14248"
              "nats://localhost:24248"
              "nats://localhost:34248"
            ];
          };
          jetstream = {
            max_mem = "1G";
            max_file = "10G";
          };
        };
      '';
      description = ''
        Declarative NATS configuration. See the
        [
        NATS documentation](https://docs.nats.io/nats-server/configuration) for a list of options.
      '';
    };
  };

  config = {
    outputs.settings.processes."${name}" = {
      command = "${lib.getExe config.package} -c ${validateConfig configFile} -sd ${config.dataDir}";
      readiness_probe =
        let
          # https://docs.nats.io/running-a-nats-service/nats_admin/monitoring#health-healthz
          nats-ready = pkgs.writeShellApplication {
            runtimeInputs = with pkgs; [
              curl
              gnugrep
              jq
            ];
            name = "nats-ready";
            text = ''
              curl -sSfN http://localhost:${toString config.settings.monitor_port}/healthz | jq '.status' | grep "ok"
            '';
          };
        in
        {
          exec.command = lib.getExe nats-ready;
          initial_delay_seconds = 2;
          period_seconds = 10;
          timeout_seconds = 4;
          success_threshold = 1;
          failure_threshold = 5;
        };
      # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
      availability = {
        restart = "on_failure";
        max_restarts = 5;
      };
    };
  };
}
