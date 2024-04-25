# Based on: https://github.com/cachix/devenv/blob/main/src/modules/services/mysql.nix
{ pkgs, lib, name, config, ... }:
with lib.types; let
  inherit (lib) types;
  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
in
{
  options = {
    enable = lib.mkEnableOption "MySQL process and expose utilities";

    package = lib.mkOption {
      type = types.package;
      description = "Which package of MySQL to use";
      default = pkgs.mariadb;
      defaultText = lib.literalExpression "pkgs.mariadb";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The mysql data directory";
    };

    socketDir = lib.mkOption {
      type = types.nullOr types.str;
      default = config.dataDir;
      description = "The mysql socket directory. If null, defaults to dataDir.";
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        MySQL configuration.
      '';
      example = literalExpression ''
        {
          mysqld = {
            key_buffer_size = "6G";
            table_cache = 1600;
            log-error = "/var/log/mysql_err.log";
            plugin-load-add = [ "server_audit" "ed25519=auth_ed25519" ];
          };
          mysqldump = {
            quick = true;
            max_allowed_packet = "16M";
          };
        }
      '';
    };

    initialScript = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Initial SQL commands to run after `initialDatabases` and `ensureUsers`. This can be multiple
        SQL expressions separated by a semi-colon.
      '';
      example = ''
        CREATE USER foo IDENTIFIED BY 'password@123';
        CREATE USER bar;
      '';
    };

    initialDatabases = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = ''
              The name of the database to create.
            '';
          };
          schema = lib.mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              The initial schema of the database; if null (the default),
              an empty database is created.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        List of database names and their initial schemas that should be used to create databases on the first startup
        of MySQL. The schema attribute is optional: If not specified, an empty database is created.
      '';
      example = literalExpression ''
        [
          { name = "foodatabase"; schema = ./foodatabase.sql; }
          { name = "bardatabase"; }
        ]
      '';
    };

    importTimeZones = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to import tzdata on the first startup of the mysql server
      '';
    };

    ensureUsers = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = ''
              Name of the user to ensure.
            '';
          };

          password = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Password of the user to ensure.
            '';
          };

          ensurePermissions = lib.mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Permissions to ensure for the user, specified as attribute set.
              The attribute names specify the database and tables to grant the permissions for,
              separated by a dot. You may use wildcards here.
              The attribute values specfiy the permissions to grant.
              You may specify one or multiple comma-separated SQL privileges here.
              For more information on how to specify the target
              and on which privileges exist, see the
              [GRANT syntax](https://mariadb.com/kb/en/library/grant/).
              The attributes are used as `GRANT ''${attrName} ON ''${attrValue}`.
            '';
            example = literalExpression ''
              {
                "database.*" = "ALL PRIVILEGES";
                "*.*" = "SELECT, LOCK TABLES";
              }
            '';
          };
        };
      });
      default = [ ];
      description = ''
        Ensures that the specified users exist and have at least the ensured permissions.
        The MySQL users will be identified using Unix socket authentication. This authenticates the Unix user with the
        same name only, and that without the need for a password.
        This option will never delete existing users or remove permissions, especially not when the value of this
        option is changed. This means that users created and permissions assigned once through this option or
        otherwise have to be removed manually.
      '';
      example = literalExpression ''
        [
          {
            name = "devenv";
            ensurePermissions = {
              "devenv.*" = "ALL PRIVILEGES";
            };
          }
        ]
      '';
    };
    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes =
          let
            isMariaDB = lib.getName config.package == lib.getName pkgs.mariadb;
            configFile = format.generate "my.cnf" config.settings;
            mysqlOptions = "--defaults-file=${configFile}";
            mysqldOptions = "${mysqlOptions} --datadir=${config.dataDir} --basedir=${config.package}";
            envs = ''
              MYSQL_HOME=$(${pkgs.coreutils}/bin/realpath ${config.dataDir})
              MYSQL_UNIX_PORT=$(${pkgs.coreutils}/bin/realpath ${config.socketDir + "/mysql.sock"})
              MYSQLX_UNIX_PORT=$(${pkgs.coreutils}/bin/realpath ${config.socketDir + "/mysqlx.sock"})

              export MYSQL_HOME
              export MYSQL_UNIX_PORT
              export MYSQLX_UNIX_PORT

              ${lib.optionalString (lib.hasAttrByPath [ "mysqld" "port" ] config.settings) "export MYSQL_TCP_PORT=${toString config.settings.mysqld.port}"}
            '';

            initDatabaseCmd =
              if isMariaDB
              then "mysql_install_db ${mysqldOptions} --auth-root-authentication-method=normal"
              else "mysqld ${mysqldOptions} --default-time-zone=SYSTEM --initialize-insecure";

            importTimeZones =
              if (config.importTimeZones != null)
              then config.importTimeZones
              else lib.hasAttrByPath [ "settings" "mysqld" "default-time-zone" ] config;

            configureTimezones = ''
              # Start a temp database with the default-time-zone to import tz data
              # and hide the temp database from the configureScript by setting a custom socket
              CONFIG_SOCKET="$(${pkgs.coreutils}/bin/realpath ${config.socketDir + "/config.sock"})"
              nohup mysqld ${mysqldOptions} --socket="$CONFIG_SOCKET" --skip-networking --default-time-zone=SYSTEM &

              while ! MYSQL_PWD="" mysqladmin --socket="$CONFIG_SOCKET" ping -u root --silent; do
                sleep 1
              done
              mysql_tzinfo_to_sql ${pkgs.tzdata}/share/zoneinfo | MYSQL_PWD="" mysql --socket="$CONFIG_SOCKET" -u root mysql
              # Shutdown the temp database
              MYSQL_PWD="" mysqladmin --socket="$CONFIG_SOCKET" shutdown -u root
            '';

            startScript = pkgs.writeShellApplication {
              name = "start-mysql";
              runtimeInputs = [ config.package pkgs.coreutils ];
              text = ''
                set -euo pipefail

                if [[ ! -d ${config.socketDir} ]]; then
                  mkdir -p ${config.socketDir}
                fi
                if [[ ! -d ${config.dataDir} || ! -f ${config.dataDir}/ibdata1 ]]; then
                  mkdir -p ${config.dataDir}
                  ${initDatabaseCmd}
                  ${lib.optionalString importTimeZones configureTimezones}
                fi
                ${envs}
                exec mysqld ${mysqldOptions}
              '';
            };

            runInitialScript = lib.optionalString (config.initialScript != null) ''echo ${lib.escapeShellArg config.initialScript} | MYSQL_PWD="" mysql -u root -N
'';

            configureScript = pkgs.writeShellApplication {
              name = "configure-mysql";
              runtimeInputs = with pkgs; [ config.package coreutils findutils ];
              text = ''
                set -euo pipefail
                ${envs}
                ${lib.concatMapStrings (database: ''
                    # Create initial databases
                    exists="$(
                      MYSQL_PWD="" mysql -u root -sB information_schema \
                        <<< 'select count(*) from schemata where schema_name = "${database.name}"'
                    )"
                    if [[ "$exists" -eq 0 ]]; then
                      echo "Creating initial database: ${database.name}"
                      ( echo "create database ${database.name};"
                        ${lib.optionalString (database.schema != null) ''
                      echo "use ${database.name};"
                      # TODO: this silently falls through if database.schema does not exist,
                      # we should catch this somehow and exit, but can't do it here because we're in a subshell.
                      if [ -f "${database.schema}" ]
                      then
                          cat ${database.schema}
                      elif [ -d "${database.schema}" ]
                      then
                          # -print0/-0 is used because of: https://www.shellcheck.net/wiki/SC2038
                          find ${database.schema} -type f -name '*.sql' -print0 | xargs -0 cat
                      fi
                    ''}
                      ) | MYSQL_PWD="" mysql -u root -N
                    else
                      echo "Database ${database.name} exists, skipping creation."
                    fi
                  '')
                  config.initialDatabases}

                ${lib.concatMapStrings (user: ''
                    echo "Adding user: ${user.name}"
                    ${lib.optionalString (user.password != null) "password='${user.password}'"}
                    ( echo "CREATE USER IF NOT EXISTS '${user.name}'@'localhost' ${lib.optionalString (user.password != null) "IDENTIFIED BY '$password'"};"
                      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (database: permission: ''
                        echo "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
                      '')
                      user.ensurePermissions)}
                    ) | MYSQL_PWD="" mysql -u root -N
                  '')
                  config.ensureUsers}

                ${runInitialScript}
              '';
            };
          in
          {
            "${name}" =
              {
                command = startScript;

                readiness_probe = {
                  # Turns out using `--defaults-file` alone doesn't make the readiness_probe work unless `MYSQL_UNIX_PORT` is set.
                  # Hence the use of `--socket`.
                  exec.command = "${config.package}/bin/mysqladmin --socket=${config.socketDir}/mysql.sock ping -h localhost";
                  initial_delay_seconds = 2;
                  period_seconds = 10;
                  timeout_seconds = 4;
                  success_threshold = 1;
                  failure_threshold = 5;
                };
                namespace = name;

                # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
                availability.restart = "on_failure";
              };
            "${name}-configure" = {
              command = configureScript;
              namespace = name;
              depends_on."${name}".condition = "process_healthy";
            };
          };
      };
    };
  };
}
