# Based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/apache-kafka.nix
{ config, lib, pkgs, name, ... }:
let
  mkPropertyString =
    let
      render = {
        bool = lib.boolToString;
        int = toString;
        list = lib.concatMapStringsSep "," mkPropertyString;
        string = lib.id;
      };
    in
    v: render.${lib.strings.typeOf v} v;

  stringlySettings = lib.mapAttrs (_: mkPropertyString)
    (lib.filterAttrs (_: v: v != null) config.settings);

  generator = (pkgs.formats.javaProperties { }).generate;
in
with lib;
{
  options = {
    enable = mkEnableOption (lib.mdDoc "Apache Kafka event streaming broker");

    port = mkOption {
      description = lib.mdDoc "Port number the broker should listen on.";
      default = 9092;
      type = types.port;
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = lib.mdDoc "The apache-kafka data directory";
    };

    settings = mkOption {
      description = lib.mdDoc ''
        [Kafka broker configuration](https://kafka.apache.org/documentation.html#brokerconfigs)
        {file}`server.properties`.

        Note that .properties files contain mappings from string to string.
        Keys with dots are NOT represented by nested attrs in these settings,
        but instead as quoted strings (ie. `settings."broker.id"`, NOT
        `settings.broker.id`).
      '';
      type = types.submodule {
        freeformType = with types; let
          primitive = oneOf [ bool int str ];
        in
        lazyAttrsOf (nullOr (either primitive (listOf primitive)));

        options = {
          "broker.id" = mkOption {
            description = lib.mdDoc "Broker ID. -1 or null to auto-allocate in zookeeper mode.";
            default = null;
            type = with types; nullOr int;
          };

          "log.dirs" = mkOption {
            description = lib.mdDoc "Log file directories.";
            # Deliberaly leave out old default and use the rewrite opportunity
            # to have users choose a safer value -- /tmp might be volatile and is a
            # slightly scary default choice.
            # default = [ "/tmp/apache-kafka" ];
            type = with types; listOf str;
            default = [ (config.dataDir + "/logs") ];
          };

          "listeners" = mkOption {
            description = lib.mdDoc ''
              Kafka Listener List.
              See [listeners](https://kafka.apache.org/documentation/#brokerconfigs_listeners).
            '';
            type = types.listOf types.str;
            default = [ "PLAINTEXT://localhost:${builtins.toString config.port}" ];
          };
        };
      };
    };

    clusterId = mkOption {
      description = lib.mdDoc ''
        KRaft mode ClusterId used for formatting log directories. Can be generated with `kafka-storage.sh random-uuid`
      '';
      type = with types; nullOr str;
      default = null;
    };

    configFiles.serverProperties = mkOption {
      description = lib.mdDoc ''
        Kafka server.properties configuration file path.
        Defaults to the rendered `settings`.
      '';
      type = types.path;
      default = generator "server.properties" stringlySettings;
    };

    configFiles.log4jProperties = mkOption {
      description = lib.mdDoc "Kafka log4j property configuration file path";
      type = types.path;
      default = pkgs.writeText "log4j.properties" config.log4jProperties;
      defaultText = ''pkgs.writeText "log4j.properties" config.log4jProperties'';
    };

    formatLogDirs = mkOption {
      description = lib.mdDoc ''
        Whether to format log dirs in KRaft mode if all log dirs are
        unformatted, ie. they contain no meta.properties.
      '';
      type = types.bool;
      default = false;
    };

    formatLogDirsIgnoreFormatted = mkOption {
      description = lib.mdDoc ''
        Whether to ignore already formatted log dirs when formatting log dirs,
        instead of failing. Useful when replacing or adding disks.
      '';
      type = types.bool;
      default = false;
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

    package = mkPackageOption pkgs "apacheKafka" { };

    jre = mkOption {
      description = lib.mdDoc "The JRE with which to run Kafka";
      default = config.package.passthru.jre;
      defaultText = literalExpression "pkgs.apacheKafka.passthru.jre";
      type = types.package;
    };
  };
  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            let
              startScript = pkgs.writeShellApplication {
                name = "start-kafka";
                runtimeInputs = [ config.jre ];
                text = ''
                  java \
                    -cp "${config.package}/libs/*" \
                    -Dlog4j.configuration=file:${config.configFiles.log4jProperties} \
                    ${toString config.jvmOptions} \
                    kafka.Kafka \
                    ${config.configFiles.serverProperties}
                '';
              };
            in
            {
              command = startScript;

              readiness_probe = {
                # TODO: need to find a better way to check if kafka is ready. Maybe use one of the scripts in bin?
                exec.command = "${pkgs.netcat.nc}/bin/nc -z localhost ${builtins.toString config.port}";
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
