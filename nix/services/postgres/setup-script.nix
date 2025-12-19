{ config, pkgs, lib }:
let
  setupInitialSchema = dbName: schema: ''
    echo "Applying database schema on ${dbName}"
    if [ -f "${schema}" ]
    then
      echo "Running file ${schema}"
      awk 'NF' "${schema}" | psql_with_args -d ${dbName}
    elif [ -d "${schema}" ]
    then
      # Read sql files in version order. Apply one file
      # at a time to handle files where the last statement
      # doesn't end in a ;.
      find "${schema}"/*.sql | while read -r f ; do
        echo "Applying sql file: $f"
        awk 'NF' "$f" | psql_with_args -d ${dbName}
      done
    else
      echo "ERROR: Could not determine how to apply schema with ${schema}"
      exit 1
    fi
  '';
  setupInitialDatabases =
    if config.initialDatabases != [ ] then
      (lib.concatMapStrings
        (database: ''
          echo "Checking presence of database: ${database.name}"
          # Create initial databases
          dbAlreadyExists=$(
            echo "SELECT 1 as exists FROM pg_database WHERE datname = '${database.name}';" | \
            psql_with_args -d postgres | \
            grep -c 'exists = "1"' || true
          )
          echo "$dbAlreadyExists"
          if [ 1 -ne "$dbAlreadyExists" ]; then
            echo "Creating database: ${database.name}"
            echo 'create database "${database.name}";' | psql_with_args -d postgres
            ${lib.optionalString (database.schemas != null)
              (lib.concatMapStrings (schema: setupInitialSchema (database.name) schema) database.schemas)}
          fi
        '')
        config.initialDatabases)
    else
      lib.optionalString config.createDatabase ''
        echo "CREATE DATABASE \"''${USER:-$(id -nu)}\";" | psql_with_args -d postgres '';


  runInitialScript =
    let
      scriptCmd = sqlScript: ''
        echo "${sqlScript}" | psql_with_args -d postgres
      '';
    in
    {
      before = with config.initialScript;
        lib.optionalString (before != null) (scriptCmd before);
      after = with config.initialScript;
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
    (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") (config.defaultSettings // config.settings)));

  initdbArgs =
    config.initdbArgs
    ++ (lib.optionals (config.superuser != null) [ "-U" config.superuser ])
    ++ [ "-D" "\"${config.dataDir}\"" ];
in
(pkgs.writeShellApplication {
  name = "setup-postgres";
  runtimeInputs = with pkgs; [ config.package coreutils gnugrep gawk findutils ];
  text = ''
    set -x
    # Execute the `psql` command with default arguments
    function psql_with_args() {
      psql ${lib.optionalString (config.superuser != null) "-U ${config.superuser}"} -v "ON_ERROR_STOP=1" "$@"
    }
    # Setup postgres ENVs
    export PGDATA="${config.dataDir}"
    export PGPORT="${toString config.port}"
    POSTGRES_RUN_INITIAL_SCRIPT="false"


    if [[ ! -d "$PGDATA" ]]; then
      initdb ${lib.concatStringsSep " " initdbArgs}
      POSTGRES_RUN_INITIAL_SCRIPT="true"
      echo
      echo "PostgreSQL initdb process complete."
      echo
    fi

    # Setup config
    echo "Setting up postgresql.conf"
    cp ${configFile} "$PGDATA/postgresql.conf"
    # Create socketDir if it doesn't exist and it is not empty
    ${lib.optionalString (config.socketDir != "") ''
      if [ ! -d "${config.socketDir}" ]; then
        echo "Creating socket directory"
        mkdir -p "${config.socketDir}"
      fi
    ''}

    if [[ "$POSTGRES_RUN_INITIAL_SCRIPT" = "true" ]]; then
      echo
      echo "PostgreSQL is setting up the initial database."
      echo
      ${ if config.socketDir != "" then ''
        PGHOST=$(mktemp -d "$(readlink -f "${config.socketDir}")/pg-init-XXXXXX")
      '' else ''
        PGHOST=$(mktemp -d /tmp/pg-init-XXXXXX)
      ''
      }
      export PGHOST

      function remove_tmp_pg_init_sock_dir() {
        if [[ -d "$1" ]]; then
          rm -rf "$1"
        fi
      }
      trap 'remove_tmp_pg_init_sock_dir "$PGHOST"' EXIT

      trap 'pg_ctl -D "$PGDATA" -m fast -w stop' EXIT

      pg_ctl -D "$PGDATA" -w start -o "-c unix_socket_directories=\"$PGHOST\" -c listen_addresses= -p ${toString config.port}"

      ${runInitialScript.before}
      ${setupInitialDatabases}
      ${runInitialScript.after}
    else
      echo
      echo "PostgreSQL database directory appears to contain a database; Skipping initialization"
      echo
    fi
    unset POSTGRES_RUN_INITIAL_SCRIPT
  '';
})
