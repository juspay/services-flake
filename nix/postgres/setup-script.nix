{ config, pkgs, lib, postgresPkg }:
let
  setupInitialDatabases =
    if config.initialDatabases != [ ] then
      (lib.concatMapStrings
        (database: ''
          echo "Checking presence of database: ${database.name}"
          # Create initial databases
          dbAlreadyExists=$(
            echo "SELECT 1 as exists FROM pg_database WHERE datname = '${database.name}';" | \
            psql -d postgres | \
            ${pkgs.gnugrep}/bin/grep -c 'exists = "1"' || true
          )
          echo $dbAlreadyExists
          if [ 1 -ne "$dbAlreadyExists" ]; then
            echo "Creating database: ${database.name}"
            echo 'create database "${database.name}";' | psql -d postgres


            ${lib.optionalString (database.schema != null) ''
            echo "Applying database schema on ${database.name}"
            if [ -f "${database.schema}" ]
            then
              echo "Running file ${database.schema}"
              ${pkgs.gawk}/bin/awk 'NF' "${database.schema}" | psql -d ${database.name}
            elif [ -d "${database.schema}" ]
            then
              # Read sql files in version order. Apply one file
              # at a time to handle files where the last statement
              # doesn't end in a ;.
              ls -1v "${database.schema}"/*.sql | while read f ; do
                echo "Applying sql file: $f"
                ${pkgs.gawk}/bin/awk 'NF' "$f" | psql -d ${database.name}
              done
            else
              echo "ERROR: Could not determine how to apply schema with ${database.schema}"
              exit 1
            fi
            ''}
          fi
        '')
        config.initialDatabases)
    else
      lib.optionalString config.createDatabase ''
        echo "CREATE DATABASE ''${USER:-$(id -nu)};" | psql -d postgres '';
  runInitialScript =
    let
      scriptCmd = sqlScript: ''
        echo "${sqlScript}" | psql -d postgres
      '';
    in
    {
      before = with config.initialScript;
        lib.optionalString (before != null) (scriptCmd before);
      after = with config.initialScript;
        lib.optionalString (after != null) (scriptCmd after);
    };
  setupScript = pkgs.writeShellScriptBin "setup-postgres" ''
    set -euo pipefail
    export PATH=${postgresPkg}/bin:${pkgs.coreutils}/bin

    ${runInitialScript.before}
    ${setupInitialDatabases}
    ${runInitialScript.after}

  '';
in
setupScript
