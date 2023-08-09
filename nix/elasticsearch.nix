# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/elasticsearch.nix
# Note: 
#   To use elastic search you will need the following inside your `perSystem`, if not already configured:
#   { 
#     _module.args.pkgs = import inputs.nixpkgs {
#        inherit system;
#        # Required for elastic search
#        config.allowUnfree = true;
#      };
#   }
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    description = ''
      Configure elasticsearch. This will start a single-node cluster by default.
      Note: 
      To use elastic search you will need the following inside your `perSystem`, if not already configured:
      { 
        _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            # Required for elastic search
            config.allowUnfree = true;
          };
      } 
    '';
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "elasticsearch7" { };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "Directory where elasticsearch stores its data.";
    };

    listenAddress = lib.mkOption {
      description = "Elasticsearch listen address.";
      default = "127.0.0.1";
      type = types.str;
    };

    port = lib.mkOption {
      description = "Elasticsearch port to listen for HTTP traffic.";
      default = 9200;
      type = types.int;
    };

    tcp_port = lib.mkOption {
      description = "Elasticsearch port for the node to node communication.";
      default = 9300;
      type = types.int;
    };

    cluster_name = lib.mkOption {
      description =
        "Elasticsearch name that identifies your cluster for auto-discovery.";
      default = "elasticsearch";
      type = types.str;
    };

    single_node = lib.mkOption {
      description = "Start a single-node cluster";
      default = true;
      type = types.bool;
    };

    extraConf = lib.mkOption {
      description = "Extra configuration for elasticsearch.";
      default = "";
      type = types.str;
      example = ''
        node.name: "elasticsearch"
        node.master: true
        node.data: false
      '';
    };

    logging = lib.mkOption {
      description = "Elasticsearch logging configuration.";
      default = ''
        logger.action.name = org.elasticsearch.action
        logger.action.level = info
        appender.console.type = Console
        appender.console.name = console
        appender.console.layout.type = PatternLayout
        appender.console.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] %marker%m%n
        rootLogger.level = info
        rootLogger.appenderRef.console.ref = console
      '';
      type = types.str;
    };

    extraCmdLineOptions = lib.mkOption {
      description =
        "Extra command line options for the elasticsearch launcher.";
      default = [ ];
      type = types.listOf types.str;
    };

    extraJavaOptions = lib.mkOption {
      description = "Extra command line options for Java.";
      default = [ ];
      type = types.listOf types.str;
      example = [ "-Djava.net.preferIPv4Stack=true" ];
    };

    plugins = lib.mkOption {
      description = "Extra elasticsearch plugins";
      default = [ ];
      type = types.listOf types.package;
      example =
        lib.literalExpression "[ pkgs.elasticsearchPlugins.discovery-ec2 ]";
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes."${name}" =
          let
            es7 = builtins.compareVersions config.package.version "7" >= 0;

            esConfig = ''
              network.host: ${config.listenAddress}
              cluster.name: ${config.cluster_name}
              ${lib.optionalString config.single_node "discovery.type: single-node"}
              http.port: ${toString config.port}
              transport.port: ${toString config.tcp_port}
              ${config.extraConf}
            '';

            elasticsearchYml = pkgs.writeTextFile {
              name = "elasticsearch.yml";
              text = esConfig;
            };

            loggingConfigFilename = "log4j2.properties";
            loggingConfigFile = pkgs.writeTextFile {
              name = loggingConfigFilename;
              text = config.logging;
            };

            esPlugins = pkgs.buildEnv {
              name = "elasticsearch-plugins";
              paths = config.plugins;
              postBuild = "${pkgs.coreutils}/bin/mkdir -p $out/plugins";
            };

            startScript = pkgs.writeShellScript "es-startup" ''
              set -e

              export ES_HOME=$(${pkgs.coreutils}/bin/realpath ${config.dataDir})
              export ES_JAVA_OPTS="${toString config.extraJavaOptions}"
              export ES_PATH_CONF="${config.dataDir}/config"
              mkdir -m 0700 -p "${config.dataDir}"
              # Install plugins
              rm -f "${config.dataDir}/plugins"
              ln -sf ${esPlugins}/plugins "${config.dataDir}/plugins"
              rm -f "${config.dataDir}/lib"
              ln -sf ${config.package}/lib "${config.dataDir}/lib"
              rm -f "${config.dataDir}/modules"
              ln -sf ${config.package}/modules "${config.dataDir}/modules"

              # Create config dir
              mkdir -m 0700 -p "${config.dataDir}/config"
              rm -f "${config.dataDir}/config/elasticsearch.yml"
              cp ${elasticsearchYml} "${config.dataDir}/config/elasticsearch.yml"
              rm -f "${config.dataDir}/logging.yml"
              rm -f "${config.dataDir}/config/${loggingConfigFilename}"
              cp ${loggingConfigFile} "${config.dataDir}/config/${loggingConfigFilename}"

              mkdir -p "${config.dataDir}/scripts"
              rm -f "${config.dataDir}/config/jvm.options"

              cp ${config.package}/config/jvm.options "${config.dataDir}/config/jvm.options"

              # Create log dir
              mkdir -m 0700 -p "${config.dataDir}/logs"

              # Start it
              exec ${config.package}/bin/elasticsearch ${toString config.extraCmdLineOptions}
            '';

          in
          {
            command = "${startScript}";

            readiness_probe = {
              exec.command = "${pkgs.curl}/bin/curl -f -k http://${config.listenAddress}:${toString config.port}";
              initial_delay_seconds = 15;
              period_seconds = 10;
              timeout_seconds = 2;
              success_threshold = 1;
              failure_threshold = 5;
            };

            # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
            availability.restart = "on_failure";
          };
      };
    };
  };
}
