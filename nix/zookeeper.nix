{ config, lib, pkgs, name, ... }:

with lib;
{
  options = {
    enable = mkEnableOption (lib.mdDoc "Zookeeper");

    port = mkOption {
      description = lib.mdDoc "Zookeeper Client port.";
      default = 2181;
      type = types.port;
    };

    dataDir = mkOption {
      type = types.str;
      default = "./data/${name}";
      description = lib.mdDoc ''
        Data directory for Zookeeper
      '';
    };

    id = mkOption {
      description = lib.mdDoc "Zookeeper ID.";
      default = 0;
      type = types.int;
    };

    purgeInterval = mkOption {
      description = lib.mdDoc ''
        The time interval in hours for which the purge task has to be triggered. Set to a positive integer (1 and above) to enable the auto purging.
      '';
      default = 1;
      type = types.int;
    };

    extraConf = mkOption {
      description = lib.mdDoc "Extra configuration for Zookeeper.";
      type = types.lines;
      default = ''
        initLimit=5
        syncLimit=2
        tickTime=2000
      '';
    };

    servers = mkOption {
      description = lib.mdDoc "All Zookeeper Servers.";
      default = "";
      type = types.lines;
      example = ''
        server.0=host0:2888:3888
        server.1=host1:2888:3888
        server.2=host2:2888:3888
      '';
    };

    logging = mkOption {
      description = lib.mdDoc "Zookeeper logging configuration.";
      default = ''
        zookeeper.root.logger=INFO, CONSOLE
        log4j.rootLogger=INFO, CONSOLE
        log4j.logger.org.apache.zookeeper.audit.Log4jAuditLogger=INFO, CONSOLE
        log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender
        log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout
        log4j.appender.CONSOLE.layout.ConversionPattern=[myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n
      '';
      type = types.lines;
    };

    extraCmdLineOptions = mkOption {
      description = lib.mdDoc "Extra command line options for the Zookeeper launcher.";
      default = [ "-Dcom.sun.management.jmxremote" "-Dcom.sun.management.jmxremote.local.only=true" ];
      type = types.listOf types.str;
      example = [ "-Djava.net.preferIPv4Stack=true" "-Dcom.sun.management.jmxremote" "-Dcom.sun.management.jmxremote.local.only=true" ];
    };

    preferIPv4 = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Add the -Djava.net.preferIPv4Stack=true flag to the Zookeeper server.
      '';
    };

    package = mkOption {
      description = lib.mdDoc "The zookeeper package to use";
      default = pkgs.zookeeper;
      defaultText = literalExpression "pkgs.zookeeper";
      type = types.package;
    };

    jre = mkOption {
      description = lib.mdDoc "The JRE with which to run Zookeeper";
      default = config.package.jre;
      defaultText = literalExpression "pkgs.zookeeper.jre";
      example = literalExpression "pkgs.jre";
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
              zookeeperConfig = ''
                dataDir=${config.dataDir}
                clientPort=${toString config.port}
                autopurge.purgeInterval=${toString config.purgeInterval}
                ${config.extraConf}
                ${config.servers}
                admin.enableServer=false
                4lw.commands.whitelist=stat
              '';

              configDir = pkgs.buildEnv {
                name = "zookeeper-conf";
                paths = [
                  (pkgs.writeTextDir "zoo.cfg" zookeeperConfig)
                  (pkgs.writeTextDir "log4j.properties" config.logging)
                ];
              };

              startScript = pkgs.writeShellScriptBin "start-zookeeper" ''
                ${config.jre}/bin/java \
                  -cp "${config.package}/lib/*:${configDir}" \
                  ${escapeShellArgs config.extraCmdLineOptions} \
                  -Dzookeeper.datadir.autocreate=true \
                  ${optionalString config.preferIPv4 "-Djava.net.preferIPv4Stack=true"} \
                  org.apache.zookeeper.server.quorum.QuorumPeerMain \
                  ${configDir}/zoo.cfg
              '';
            in
            {
              command = "${startScript}/bin/start-zookeeper";

              readiness_probe = {
                # TODO: need to find a better way to check if zookeeper is ready, maybe `zkCli.sh`?
                exec.command = "${pkgs.netcat.nc}/bin/nc -z localhost ${toString config.port}";
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };

              availability.restart = "on_failure";
            };
        };
      };
    };

  };
}
