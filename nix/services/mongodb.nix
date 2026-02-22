{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "mongodb-ce" { };

    bind = lib.mkOption {
      type = types.nullOr types.str;
      default = "127.0.0.1";
      description = ''
        The IP interface to bind to.
        `null` means "all interfaces".
      '';
      example = "127.0.0.1";
    };

    port = lib.mkOption {
      type = types.port;
      default = 27017;
      description = ''
        The TCP port to accept connections.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = "default";
      description = ''
        The name of the first user to create in
        Mongo.
      '';
      example = "my_user";
    };

    password = lib.mkOption {
      type = types.str;
      default = "password";
      description = ''
        The password of the user to configure
        for initial access.
      '';
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Additional text to be appended to `mongodb.conf`.";
    };

    replicaSetName = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The name of the replica set to configure.";
      example = "rs0";
    };

    ulimit = lib.mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = "The maximum number of open file descriptors for mongod.";
    };
  };

  config.outputs.settings.processes =
    let
      mongoshArgs =
        (lib.optional (lib.elem config.bind [ null "0.0.0.0" "::" ]) "--host=${config.bind}")
        ++
        [
          "--port=${toString config.port}"
        ];
      mongoshCommand = "${lib.getExe pkgs.mongosh} ${lib.escapeShellArgs mongoshArgs}";
    in
    {
      "${name}" =
        let
          mongoConfig = pkgs.writeText "mongodb.conf" ''
            net.port: ${toString config.port}
            net.bindIp: ${config.bind}
            storage.dbPath: ${config.dataDir}
            ${lib.optionalString (config.replicaSetName != null) ''
              replication:
                replSetName: "${config.replicaSetName}"
            ''}
            ${config.extraConfig}
          '';

          startScript = pkgs.writeShellApplication {
            name = "start-mongodb";
            runtimeInputs = [ pkgs.coreutils config.package ];
            text = ''
              export MONGODATA="${config.dataDir}"

              if [[ ! -d "$MONGODATA" ]]; then
                mkdir -p "$MONGODATA"
              fi

              ${if config.ulimit != null then "ulimit -n ${toString config.ulimit}" else ""}

              exec mongod --config "${mongoConfig}"
            '';
          };
        in
        {
          command = startScript;

          readiness_probe = {
            exec.command = "${mongoshCommand} --eval 'db.version()' > /dev/null 2>&1";
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
      "${name}-configure" =
        let
          replSetConfig = ''{ _id: "${config.replicaSetName}", members: [ { _id: 0, host: "${config.bind}:${toString config.port}" } ] }'';
          configScript = pkgs.writeShellApplication {
            name = "configure-mongo";
            text = ''
              ${lib.optionalString (config.replicaSetName != null) ''
                # Configure replica set
                echo "Configuring replica set ${config.replicaSetName}..."

                # Check if replica set is already configured
                if ! ${mongoshCommand} --eval 'try { rs.status().ok } catch (e) { quit(10) }' --quiet; then
                  # try initiate, which will fail if already initiated, in which case we reconfig with force:true in case host\port changes
                  ${mongoshCommand} --eval 'try { rs.initiate(${replSetConfig}) } catch (e) { rs.reconfig(${replSetConfig}, { force: true }) }'

                  echo "Waiting for replica set to stabilize..."
                  success=0
                  for i in $(seq 1 30); do
                    # Try to check if this node has become primary.
                    # rs.isMaster().ismaster returns true if primary, false otherwise.
                    # If the command fails (e.g. server not ready), mongosh will exit with a non-zero code due to quit(10).
                    if ${mongoshCommand} --eval 'try { if (rs.isMaster().ismaster) { quit(0) } else { quit(1) } } catch (e) { quit(10) }' --quiet; then
                      echo "Replica set primary is active."
                      success=1
                      break
                    fi
                    echo "Attempt $i/30: Replica set not yet stable, retrying in 1 seconds..."
                    sleep 1
                  done

                  if [[ $success -eq 0 ]]; then
                    echo "Error: Replica set did not stabilize after 30 seconds."
                    exit 1
                  fi
                else
                  echo "Replica set ${config.replicaSetName} already configured."
                fi
              ''}

              # Configure user
              if ! test -e "${config.dataDir}/.auth_configured"; then
                ${mongoshCommand} <<EOF
                  use admin
                  db.createUser({
                    user: "${config.user}",
                    pwd: "${config.password}",
                    roles: [
                      { role: "userAdminAnyDatabase", db: "admin" },
                      { role: "dbAdminAnyDatabase", db: "admin" },
                      { role: "readWriteAnyDatabase", db: "admin" }
                    ]
                  })
              EOF
                touch "${config.dataDir}/.auth_configured"
              else
                echo "Database previously configured. If this is in error, remove"
                echo "the file at '${config.dataDir}/.auth_configured' and restart"
                echo "this process."
              fi
            '';
          };
        in
        {
          command = configScript;
          depends_on."${name}".condition = "process_healthy";
        };
    };
}
