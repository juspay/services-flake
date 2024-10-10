{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "mongodb" { };

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
  };

  config = {
    outputs = {
      settings = {
        processes = {
          "${name}" =
            let
              mongoConfig = pkgs.writeText "mongodb.conf" ''
                net.port: ${toString config.port}
                net.bindIp: ${config.bind}
                storage.dbPath: ${config.dataDir}
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

                  exec mongod --config "${mongoConfig}"
                '';
              };
            in
            {
              command = startScript;

              readiness_probe = {
                exec.command = "${pkgs.mongosh}/bin/mongosh --eval \"db.version()\" > /dev/null 2>&1";
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
              configScript = pkgs.writeShellApplication {
                name = "configure-mongo";
                text = ''
                  if ! test -e "${config.dataDir}/.auth_configured"; then
                    ${pkgs.mongosh}/bin/mongosh <<EOF
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
      };
    };
  };
}
