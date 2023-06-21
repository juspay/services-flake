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
    type = lib.types.submodule ({ config, ... }: {
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
          default = "./data/${config.name}";
          description = "The DB data directory";
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

        settings = lib.mkOption {
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
          type = types.nullOr types.str;
          default = null;
          description = ''
            Initial SQL commands to run during database initialization. This can be multiple
            SQL expressions separated by a semi-colon.

            NOTE: initialScript is run /before/ initialDatabases are created.
          '';
          example = lib.literalExpression ''
            CREATE USER postgres SUPERUSER;
            CREATE USER bar;
          '';
        };
      };
    });
  };
  config = let cfg = config.services.postgres; in lib.mkIf cfg.enable {
    settings.processes =
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
      {
        # DB initialization
        "${cfg.name}-init".command =
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
              if cfg.initialScript != null then
                ''
                  echo "${cfg.initialScript}" | postgres --single -E postgres
                ''
              else
                "";

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

                ${runInitialScript}
                ${setupInitialDatabases}
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
        ${cfg.name} =
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
            depends_on."${cfg.name}-init".condition = "process_completed_successfully";
            # SIGINT (= 2) for faster shutdown: https://www.postgresql.org/docs/current/server-shutdown.html
            shutdown.signal = 2;
            readiness_probe = {
              exec.command = "${postgresPkg}/bin/pg_isready -h $(readlink -f ${cfg.dataDir}) -d template1";
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
}
