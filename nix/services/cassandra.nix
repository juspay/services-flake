# Based on https://github.com/cachix/devenv/blob/fa9a708e240c6174f9fc4c6eefbc6a89ce01c350/src/modules/services/cassandra.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    package = lib.mkPackageOption pkgs "cassandra" { };

    listenAddress = lib.mkOption {
      type = types.str;
      description = "Listen address";
      default = "127.0.0.1";
      example = "127.0.0.1";
    };

    nativeTransportPort = lib.mkOption {
      type = types.port;
      description = "port for the CQL native transport to listen for clients on";
      default = 9042;
    };

    seedAddresses = lib.mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.1" ];
      description = "The addresses of hosts designated as contact points of the cluster";
    };

    clusterName = lib.mkOption {
      type = types.str;
      default = "Test Cluster";
      description = "The name of the cluster";
    };

    allowClients = lib.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enables or disables the native transport server (CQL binary protocol)
      '';
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      example =
        {
          commitlog_sync_batch_window_in_ms = 3;
        };
      description = ''
        Extra options to be merged into `cassandra.yaml` as nix attribute set.
      '';
    };

    jvmOpts = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Options to pass to the JVM through the JVM_OPTS environment variable";
    };

    defaultExtraConfig = lib.mkOption {
      type = yamlFormat.type;
      internal = true;
      readOnly = true;
      default = {
        start_native_transport = config.allowClients;
        listen_address = config.listenAddress;
        native_transport_port = config.nativeTransportPort;
        commitlog_sync = "batch";
        commitlog_sync_batch_window_in_ms = 2;
        cluster_name = config.clusterName;
        partitioner = "org.apache.cassandra.dht.Murmur3Partitioner";
        endpoint_snitch = "SimpleSnitch";
        data_file_directories = [ "${config.dataDir}/data" ];
        commitlog_directory = "${config.dataDir}/commitlog";
        saved_caches_directory = "${config.dataDir}/saved_caches";
        hints_directory = "${config.dataDir}/hints";
        seed_provider = [
          {
            class_name = "org.apache.cassandra.locator.SimpleSeedProvider";
            parameters = [{ seeds = lib.concatStringsSep "," config.seedAddresses; }];
          }
        ];
      };
    };
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            let
              cassandraConfig = pkgs.stdenv.mkDerivation {
                name = "cassandra-config";
                cassandraYaml = yamlFormat.generate "cassandra.yaml" (
                  lib.recursiveUpdate config.defaultExtraConfig config.extraConfig
                );
                buildCommand = ''
                  mkdir -p $out
                  for d in ${config.package}/conf/*; do ln -s "$d" $out/; done
                  rm -rf $out/cassandra.y*ml
                  ln -s "$cassandraYaml" "$out/cassandra.yaml"

                  rm -rf $out/cassandra-env.sh
                  cat ${config.package}/conf/cassandra-env.sh > $out/cassandra-env.sh
                  LOCAL_JVM_OPTS="${lib.concatStringsSep " " config.jvmOpts}"
                  echo "JVM_OPTS=\"\$JVM_OPTS $LOCAL_JVM_OPTS\"" >> $out/cassandra-env.sh
                '';
              };

              startScript = pkgs.writeShellApplication {
                name = "start-cassandra";
                runtimeInputs = [ pkgs.coreutils config.package ];
                text = ''
                  set -euo pipefail

                  DATA_DIR="$(readlink -m ${config.dataDir})"
                  if [[ ! -d "$DATA_DIR" ]]; then
                    mkdir -p "$DATA_DIR"
                  fi

                  CASSANDRA_CONF="${cassandraConfig}"
                  export CASSANDRA_CONF

                  CASSANDRA_LOG_DIR="$DATA_DIR/log/"
                  mkdir -p "$CASSANDRA_LOG_DIR"
                  export CASSANDRA_LOG_DIR

                  CASSANDRA_HOME="${config.package}"
                  export CASSANDRA_HOME

                  CLASSPATH="${config.package}/lib"
                  export CLASSPATH

                  export LOCAL_JMX="yes"
                  exec cassandra -f
                '';
              };
            in
            {
              command = startScript;

              readiness_probe = {
                exec.command = ''
                  echo 'show version;' | CQLSH_HOST=${config.listenAddress} CQLSH_PORT=${toString config.nativeTransportPort} ${config.package}/bin/cqlsh
                '';
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };

              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
