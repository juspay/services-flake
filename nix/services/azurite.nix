{ config
, lib
, pkgs
, name
, ...
}:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "azurite" { };
    listenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The address for Azurite to bind to.";
    };
    blobPort = lib.mkOption {
      type = types.port;
      default = 10000;
      description = "The port for the Azurite Blob service to run on.";
    };
    queuePort = lib.mkOption {
      type = types.port;
      default = 10001;
      description = "The port for the Azurite Queue service to run on.";
    };
    tablePort = lib.mkOption {
      type = types.port;
      default = 10002;
      description = "The port for the Azurite Table service to run on.";
    };
  };

  config.outputs.settings.processes.${name} = {
    command = ''
      ${lib.getExe config.package} \
        --blobHost ${config.listenAddress} \
        --blobPort ${toString config.blobPort} \
        --queueHost ${config.listenAddress} \
        --queuePort ${toString (config.queuePort)} \
        --tableHost ${config.listenAddress} \
        --tablePort ${toString (config.tablePort)} \
        --location ${config.dataDir}/azurite \
        --skipApiVersionCheck \
        --disableTelemetry
    '';
    availability = {
      restart = "on_failure";
      max_restarts = 5;
    };
    readiness_probe = {
      exec.command = "${pkgs.netcat.nc}/bin/nc -z ${config.listenAddress} ${toString config.blobPort}";
      initial_delay_seconds = 2;
      period_seconds = 10;
      timeout_seconds = 2;
      success_threshold = 2;
      failure_threshold = 3;
    };
  };
}
