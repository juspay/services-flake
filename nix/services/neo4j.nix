{
  pkgs,
  lib,
  name,
  config,
  ...
}:
let
  inherit (lib) types;

  # Config template with $NEO4J_HOME placeholder, resolved at runtime via envsubst
  serverConfigTemplate = pkgs.writeText "neo4j.conf.template" ''
    # General
    server.default_listen_address=${config.defaultListenAddress}

    # Directories
    server.directories.data=$NEO4J_HOME/data
    server.directories.logs=$NEO4J_HOME/logs
    server.directories.run=$NEO4J_HOME/run
    server.directories.plugins=${config.package}/share/neo4j/plugins
    server.directories.lib=${config.package}/share/neo4j/lib

    # HTTP Connector
    server.http.enabled=true
    server.http.listen_address=:${toString config.httpPort}

    # HTTPS Connector (disabled for dev)
    server.https.enabled=false

    # BOLT Connector
    server.bolt.enabled=true
    server.bolt.listen_address=:${toString config.boltPort}
    server.bolt.tls_level=DISABLED

    # Default JVM parameters
    server.jvm.additional=-XX:+UseG1GC
    server.jvm.additional=-XX:-OmitStackTraceInFastThrow
    server.jvm.additional=-XX:+AlwaysPreTouch
    server.jvm.additional=-XX:+UnlockExperimentalVMOptions
    server.jvm.additional=-XX:+TrustFinalNonStaticFields
    server.jvm.additional=-XX:+DisableExplicitGC
    server.jvm.additional=-Djdk.tls.ephemeralDHKeySize=2048
    server.jvm.additional=-Djdk.tls.rejectClientInitiatedRenegotiation=true
    server.jvm.additional=-Dunsupported.dbms.udc.source=tarball

    # Extra Configuration
    ${config.extraServerConfig}
  '';
in
{
  options = {
    package = lib.mkPackageOption pkgs "neo4j" { };

    defaultListenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Default network interface to listen for incoming connections.
      '';
    };

    httpPort = lib.mkOption {
      type = types.port;
      default = 7474;
      description = ''
        The HTTP port for the Neo4j browser and REST API.
      '';
    };

    boltPort = lib.mkOption {
      type = types.port;
      default = 7687;
      description = ''
        The Bolt protocol port for Neo4j driver connections.
      '';
    };

    initialPassword = lib.mkOption {
      type = types.str;
      default = "neo4jadmin";
      description = ''
        The initial password for the `neo4j` admin user.
        Only applied before the first server start.
      '';
    };

    extraServerConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra configuration lines appended to `neo4j.conf`.

        See https://neo4j.com/docs/operations-manual/current/reference/configuration-settings/
      '';
    };
  };

  config.outputs.settings.processes."${name}" =
    let
      startScript = pkgs.writeShellApplication {
        name = "start-neo4j";
        runtimeInputs = [
          config.package
          pkgs.coreutils
        ];
        text = ''
          # Neo4j requires normalized absolute paths (no './' components)
          mkdir -p ${lib.escapeShellArg config.dataDir}
          export NEO4J_HOME
          NEO4J_HOME="$(realpath ${lib.escapeShellArg config.dataDir})"
          export NEO4J_CONF="$NEO4J_HOME/conf"

          # Setup directory structure
          mkdir -p "$NEO4J_HOME"/{conf,data,logs,run,plugins}

          # Generate config with resolved absolute paths
          sed "s|\$NEO4J_HOME|$NEO4J_HOME|g" "${serverConfigTemplate}" > "$NEO4J_CONF/neo4j.conf"

          # Set initial password (only before first start)
          if [[ ! -e "$NEO4J_HOME/.password_set" ]]; then
            neo4j-admin dbms set-initial-password \
              ${lib.escapeShellArg config.initialPassword} \
              --require-password-change=false
            touch "$NEO4J_HOME/.password_set"
          fi

          exec neo4j console
        '';
      };
    in
    {
      command = startScript;

      readiness_probe = {
        http_get = {
          host = config.defaultListenAddress;
          port = config.httpPort;
          path = "/";
        };
        initial_delay_seconds = 5;
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
