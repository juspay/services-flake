{ config, pkgs, lib, name, ... }:
{
  options = {
    package = lib.mkPackageOption pkgs "elasticmq-server-bin" { };

    nodeAddress = {
      protocol = lib.mkOption {
        type = lib.types.str;
        default = "http";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9324;
      };
      contextPath = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };

    restSqs = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          bindPort = lib.mkOption {
            type = lib.types.port;
            default = 9324;
          };
          bindHost = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0";
          };
        };
      };
      default = { };
    };

    restStats = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          bindPort = lib.mkOption {
            type = lib.types.port;
            default = 9325;
          };
          bindHost = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0";
          };
        };
      };
      default = { };
    };

    generateNodeAddress = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    extraOptions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional raw HOCON options to append.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra args to pass down to ElasticMQ.
      '';
    };
  };

  config.outputs.settings.processes."${name}" =
    let
      confFile = pkgs.writeText "elasticmq.conf" ''
        node-address.protocol = ${config.nodeAddress.protocol}
        node-address.host = ${config.nodeAddress.host}
        node-address.port = ${toString config.nodeAddress.port}
        node-address.context-path = "${config.nodeAddress.contextPath}"

        rest-sqs.enabled = ${lib.boolToString config.restSqs.enable}
        rest-sqs.bind-port = ${toString config.restSqs.bindPort}
        rest-sqs.bind-hostname = "${config.restSqs.bindHost}"

        rest-stats.enabled = ${lib.boolToString config.restStats.enable}
        rest-stats.bind-port = ${toString config.restStats.bindPort}
        rest-stats.bind-hostname = "${config.restStats.bindHost}"

        generate-node-address = ${lib.boolToString config.generateNodeAddress}

        ${config.extraOptions}
      '';
      startCommand = pkgs.writeShellApplication {
        name = "start-elasticmq";
        runtimeEnv = {
          JAVA_TOOL_OPTIONS = "-Dconfig.file=${confFile}";
        };
        text = ''
          exec ${lib.getExe config.package} ${lib.escapeShellArgs config.extraArgs}
        '';
      };
    in
    {
      command = startCommand;
      readiness_probe = lib.optionalAttrs config.restSqs.enable {
        http_get = {
          host = "127.0.0.1";
          port = config.restSqs.bindPort;
          path = "/health";
        };
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
}
