# Based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/apache-kafka.nix
{ config, lib, pkgs, name, ... }:

with lib;
{
  options = {
    enable = mkOption {
      description = lib.mdDoc "Whether to enable Apache Kafka.";
      default = false;
      type = types.bool;
    };

    brokerId = mkOption {
      description = lib.mdDoc "Broker ID.";
      default = -1;
      type = types.int;
    };

    port = mkOption {
      description = lib.mdDoc "Port number the broker should listen on.";
      default = 9092;
      type = types.port;
    };

    hostname = mkOption {
      description = lib.mdDoc "Hostname the broker should bind to.";
      default = "localhost";
      type = types.str;
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The apache-kafka data directory";
    };

    logDirs = mkOption {
      description = lib.mdDoc "Log file directories inside the data directory.";
      default = [ "/kafka-logs" ];
      type = types.listOf types.path;
    };

    zookeeper = mkOption {
      description = lib.mdDoc "Zookeeper connection string";
      default = "localhost:2181";
      type = types.str;
    };

    extraProperties = mkOption {
      description = lib.mdDoc "Extra properties for server.properties.";
      type = types.nullOr types.lines;
      default = null;
    };

    serverProperties = mkOption {
      description = lib.mdDoc ''
        Complete server.properties content. Other server.properties config
        options will be ignored if this option is used.
      '';
      type = types.nullOr types.lines;
      default = null;
    };

    log4jProperties = mkOption {
      description = lib.mdDoc "Kafka log4j property configuration.";
      default = ''
        log4j.rootLogger=INFO, stdout

        log4j.appender.stdout=org.apache.log4j.ConsoleAppender
        log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
        log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n
      '';
      type = types.lines;
    };

    jvmOptions = mkOption {
      description = lib.mdDoc "Extra command line options for the JVM running Kafka.";
      default = [ ];
      type = types.listOf types.str;
      example = [
        "-Djava.net.preferIPv4Stack=true"
        "-Dcom.sun.management.jmxremote"
        "-Dcom.sun.management.jmxremote.local.only=true"
      ];
    };

    package = mkOption {
      description = lib.mdDoc "The kafka package to use";
      default = pkgs.apacheKafka;
      defaultText = literalExpression "pkgs.apacheKafka";
      type = types.package;
    };

    jre = mkOption {
      description = lib.mdDoc "The JRE with which to run Kafka";
      default = config.package.passthru.jre;
      defaultText = literalExpression "pkgs.apacheKafka.passthru.jre";
      type = types.package;
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}" =
            let
              serverProperties =
                if config.serverProperties != null then
                  config.serverProperties
                else
                  ''
                    # Generated by services-flake
                    broker.id=${toString config.brokerId}
                    port=${toString config.port}
                    host.name=${config.hostname}
                    log.dirs=${concatStringsSep "," (builtins.map (dir: "${config.dataDir}${dir}") config.logDirs)}
                    zookeeper.connect=${config.zookeeper}
                    ${toString config.extraProperties}
                  '';

              serverConfig = pkgs.writeText "server.properties" serverProperties;
              logConfig = pkgs.writeText "log4j.properties" config.log4jProperties;

              startScript = pkgs.writeShellScriptBin "start-kafka" ''
                ${config.jre}/bin/java \
                  -cp "${config.package}/libs/*" \
                  -Dlog4j.configuration=file:${logConfig} \
                  ${toString config.jvmOptions} \
                  kafka.Kafka \
                  ${serverConfig}
              '';
            in
            {
              command = "${startScript}/bin/start-kafka";

              readiness_probe = {
                # TODO: need to find a better way to check if kafka is ready. Maybe use one of the scripts in bin?
                exec.command = "${pkgs.netcat.nc}/bin/nc -z ${config.hostname} ${toString config.port}";
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };
              namespace = name;

              availability.restart = "on_failure";
            };
        };
      };
    };

  };
}
