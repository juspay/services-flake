# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/postgres.nix
{ pkgs, lib, config, ... }:

let
  inherit (lib) types;
in
{
  options.services.postgres = lib.mkOption {
    description = ''
      Enable postgresql server
    '';
    default = { };
    type = with types; attrsOf (submodule ({ name, config, ... }: {
      options = {
        enable = lib.mkEnableOption "postgres";
        name = lib.mkOption {
          type = lib.types.str;
          default = "postgres";
          description = "Unique process name";
        };

        package = lib.mkPackageOption pkgs "postgresql" { };
        extensions = lib.mkOption {
          type = with types; nullOr (functionTo (listOf package));
          default = null;
          example = lib.literalExpression ''
            extensions: [
              extensions.pg_cron
              extensions.postgis
              extensions.timescaledb
            ];
          '';
          description = ''
            Additional PostgreSQL extensions to install.

            The available extensions are:

            ${lib.concatLines (builtins.map (x: "- " + x) (builtins.attrNames pkgs.postgresql.pkgs))}
          '';
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "./data/${name}";
          description = "The DB data directory";
        };

        hbaConf =
          let
            hbaConfSubmodule = lib.types.submodule {
              options = {
                type = lib.mkOption { type = lib.types.str; };
                database = lib.mkOption { type = lib.types.str; };
                user = lib.mkOption { type = lib.types.str; };
                address = lib.mkOption { type = lib.types.str; };
                method = lib.mkOption { type = lib.types.str; };
              };
            };
          in
          lib.mkOption {
            type = lib.types.listOf hbaConfSubmodule;
            default = [ ];
            description = ''
              A list of objects that represent the entries in the pg_hba.conf file.

              Each object has sub-options for type, database, user, address, and method.

              See the official PostgreSQL documentation for more information:
              https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
            '';
            example = [
              { type = "local"; database = "all"; user = "postgres"; address = ""; method = "md5"; }
              { type = "host"; database = "all"; user = "all"; address = "0.0.0.0/0"; method = "md5"; }
            ];
          };
        hbaConfFile =
          let
            # Default pg_hba.conf entries
            defaultHbaConf = [
              { type = "local"; database = "all"; user = "all"; address = ""; method = "trust"; }
              { type = "host"; database = "all"; user = "all"; address = "127.0.0.1/32"; method = "trust"; }
              { type = "host"; database = "all"; user = "all"; address = "::1/128"; method = "trust"; }
              { type = "local"; database = "replication"; user = "all"; address = ""; method = "trust"; }
              { type = "host"; database = "replication"; user = "all"; address = "127.0.0.1/32"; method = "trust"; }
              { type = "host"; database = "replication"; user = "all"; address = "::1/128"; method = "trust"; }
            ];

            # Merge the default pg_hba.conf entries with the user-defined entries
            hbaConf = defaultHbaConf ++ config.hbaConf;

            # Convert the pgHbaConf array to a string
            hbaConfString = ''
              # Generated by Nix
              ${"# TYPE\tDATABASE\tUSER\tADDRESS\tMETHOD\n"}
              ${lib.concatMapStrings (cnf: "  ${cnf.type}\t${cnf.database}\t${cnf.user}\t${cnf.address}\t${cnf.method}\n") hbaConf}
            '';
          in
          lib.mkOption {
            type = lib.types.package;
            internal = true;
            readOnly = true;
            description = "The `pg_hba.conf` file.";
            default = pkgs.writeText "pg_hba.conf" hbaConfString;
          };

        listen_addresses = lib.mkOption {
          type = lib.types.str;
          description = "Listen address";
          default = "";
          example = "127.0.0.1";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5432;
          description = ''
            The TCP port to accept connections.
          '';
        };

        createDatabase = lib.mkOption {
          type = types.bool;
          default = true;
          description = ''
            Create a database named like current user on startup. Only applies when initialDatabases is an empty list.
          '';
        };

        initdbArgs = lib.mkOption {
          type = types.listOf types.lines;
          default = [ "--locale=C" "--encoding=UTF8" ];
          example = [ "--data-checksums" "--allow-group-access" ];
          description = ''
            Additional arguments passed to `initdb` during data dir
            initialisation.
          '';
        };

        settings =
          lib.mkOption {
            type = with lib.types; attrsOf (oneOf [ bool float int str ]);
            default = { };
            description = ''
              PostgreSQL configuration. Refer to
              <https://www.postgresql.org/docs/11/config-setting.html#CONFIG-SETTING-CONFIGURATION-FILE>
              for an overview of `postgresql.conf`.

              String values will automatically be enclosed in single quotes. Single quotes will be
              escaped with two single quotes as described by the upstream documentation linked above.
            '';
            default = {
              listen_addresses = config.listen_addresses;
              port = config.port;
              unix_socket_directories = lib.mkDefault config.dataDir;
              hba_file = "${config.hbaConfFile}";
            };
            example = lib.literalExpression ''
              {
                log_connections = true;
                log_statement = "all";
                logging_collector = true
                log_disconnections = true
                log_destination = lib.mkForce "syslog";
              }
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
            of Postgres. The schema attribute is optional: If not specified, an empty database is created.
          '';
          example = lib.literalExpression ''
            [
              {
                name = "foodatabase";
                schema = ./foodatabase.sql;
              }
              { name = "bardatabase"; }
            ]
          '';
        };

        initialScript = lib.mkOption {
          type = types.submodule ({ config, ... }: {
            options = {
              before = lib.mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  SQL commands to run before the database initialization.
                '';
                example = lib.literalExpression ''
                  CREATE USER postgres SUPERUSER;
                  CREATE USER bar;
                '';
              };
              after = lib.mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  SQL commands to run after the database initialization.
                '';
                example = lib.literalExpression ''
                  CREATE TABLE users (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(50) NOT NULL,
                    email VARCHAR(50) NOT NULL UNIQUE
                  );
                '';
              };
            };
          });
          default = { before = null; after = null; };
          description = ''
            Initial SQL commands to run during database initialization. This can be multiple
            SQL expressions separated by a semi-colon.
          '';
        };
      };
    }));
  };
  config = let mergeMapAttrs = f: attrs: lib.mkMerge (lib.mapAttrsToList f attrs); in {
    settings.processes = mergeMapAttrs
      (name: cfg:
        let
          postgresPkg =
            if cfg.extensions != null then
              if builtins.hasAttr "withPackages" cfg.package
              then cfg.package.withPackages cfg.extensions
              else
                builtins.throw ''
                  Cannot add extensions to the PostgreSQL package.
                  `services.postgres.package` is missing the `withPackages` attribute. Did you already add extensions to the package?
                ''
            else cfg.package;
        in
        lib.mkIf cfg.enable {
          # DB initialization
          "${name}-init".command =
            let
              setupInitialDatabases =
                if cfg.initialDatabases != [ ] then
                  (lib.concatMapStrings
                    (database: ''
                      echo "Checking presence of database: ${database.name}"
                      # Create initial databases
                      dbAlreadyExists="$(
                        echo "SELECT 1 as exists FROM pg_database WHERE datname = '${database.name}';" | \
                        postgres --single -E postgres | \
                        ${pkgs.gnugrep}/bin/grep -c 'exists = "1"' || true
                      )"
                      echo $dbAlreadyExists
                      if [ 1 -ne "$dbAlreadyExists" ]; then
                        echo "Creating database: ${database.name}"
                        echo 'create database "${database.name}";' | postgres --single -E postgres


                        ${lib.optionalString (database.schema != null) ''
                        echo "Applying database schema on ${database.name}"
                        if [ -f "${database.schema}" ]
                        then
                          echo "Running file ${database.schema}"
                          ${pkgs.gawk}/bin/awk 'NF' "${database.schema}" | postgres --single -j -E ${database.name}
                        elif [ -d "${database.schema}" ]
                        then
                          # Read sql files in version order. Apply one file
                          # at a time to handle files where the last statement
                          # doesn't end in a ;.
                          ls -1v "${database.schema}"/*.sql | while read f ; do
                            echo "Applying sql file: $f"
                            ${pkgs.gawk}/bin/awk 'NF' "$f" | postgres --single -j -E ${database.name}
                          done
                        else
                          echo "ERROR: Could not determine how to apply schema with ${database.schema}"
                          exit 1
                        fi
                        ''}
                      fi
                    '')
                    cfg.initialDatabases)
                else
                  lib.optionalString cfg.createDatabase ''
                    echo "CREATE DATABASE ''${USER:-$(id -nu)};" | postgres --single -E postgres '';

            runInitialScript =
              let
                scriptCmd = sqlScript: ''
                  echo "${sqlScript}" | postgres --single -E postgres
                '';
              in
              {
                before = with cfg.initialScript;
                  lib.optionalString (before != null) (scriptCmd before);
                after = with cfg.initialScript;
                  lib.optionalString (after != null) (scriptCmd after);
              };

              toStr = value:
                if true == value then
                  "yes"
                else if false == value then
                  "no"
                else if lib.isString value then
                  "'${lib.replaceStrings [ "'" ] [ "''" ] value}'"
                else
                  toString value;

              configFile = pkgs.writeText "postgresql.conf" (lib.concatStringsSep "\n"
                (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings));

              setupScript = pkgs.writeShellScriptBin "setup-postgres" ''
                set -euo pipefail
                export PATH=${postgresPkg}/bin:${pkgs.coreutils}/bin

                if [[ ! -d "$PGDATA" ]]; then
                  set -x
                  initdb ${lib.concatStringsSep " " cfg.initdbArgs}
                  set +x

                ${runInitialScript.before}
                ${setupInitialDatabases}
                ${runInitialScript.after}
              else
                echo "Postgres data directory already exists. Skipping initialization."
              fi

                # Setup config
                set -x
                cp ${configFile} "$PGDATA/postgresql.conf"
              '';
            in
            ''
              export PGDATA="${cfg.dataDir}"
              ${lib.getExe setupScript}
            '';

          # DB process
          ${name} =
            let
              startScript = pkgs.writeShellApplication {
                name = "start-postgres";
                text = ''
                  set -x
                  export PATH="${postgresPkg}"/bin:$PATH
                  PGDATA=$(readlink -f "${cfg.dataDir}")
                  export PGDATA
                  postgres -k "$PGDATA"
                '';
              };
            in
            {
              command = startScript;
              depends_on."${name}-init".condition = "process_completed_successfully";
              # SIGINT (= 2) for faster shutdown: https://www.postgresql.org/docs/current/server-shutdown.html
              shutdown.signal = 2;
              readiness_probe = {
                # Even though we specify the data directory, we still need to specify the port because otherwise
                # pg_isready will try to connect using a socket file that ends with the default port number.
                exec.command = "${postgresPkg}/bin/pg_isready -h $(readlink -f ${cfg.dataDir}) -d template1 -p ${builtins.toString cfg.port}";
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };
              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        })
      config.services.postgres;
  };
}
