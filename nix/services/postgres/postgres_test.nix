{ pkgs, config, ... }: {
  services.postgres."pg1" = {
    enable = true;
    initialScript.before = "CREATE USER bar;";
    initialScript.after = "CREATE DATABASE foo OWNER bar;";
  };
  services.postgres."pg2" = {
    enable = true;
    socketDir = "./test/new/socket/path";
    port = 5433;
    # INFO: pg1 creates $USER database while pg2 doesn't because `initialDatabases` is present
    initialDatabases = [
      {
        name = "sample-db";
        schemas = [ ./test.sql ];
      }
    ];
  };
  services.postgres."pg3" = {
    enable = true;
    socketDir = "./test/new/socket/path2";
    listen_addresses = "";
    initialDatabases = [
      {
        name = "test-db";
      }
    ];
  };
  # avoid both the processes trying to create `data` directory at the same time
  settings.processes."pg2-init".depends_on."pg1-init".condition = "process_completed_successfully";
  settings.processes."pg3-init".depends_on."pg2-init".condition = "process_completed_successfully";
  settings.processes.test =
    let
      cfg = config.services.postgres."pg1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          echo 'SELECT version();' | psql -h 127.0.0.1
          echo 'SHOW hba_file;' | psql -h 127.0.0.1 | ${pkgs.gawk}/bin/awk 'NR==3' | grep '^ /nix/store'

          # initialScript.before test
          echo "SELECT 1 FROM pg_roles WHERE rolname = 'bar';" | psql -h 127.0.0.1 | grep -q 1

          # initialScript.after test
          echo "SELECT 1 FROM pg_database WHERE datname = 'foo';" | psql -h 127.0.0.1 | grep -q 1

          # schemas test
          echo "SELECT * from users where user_name = 'test_user';" | psql -h 127.0.0.1 -p 5433 -d sample-db | grep -q test_user
         
          # listen_addresses test
          echo "SELECT 1 FROM pg_database where datname = 'test-db';" | psql -h "$(readlink -f ${config.services.postgres.pg3.socketDir})" -d postgres | grep -q 1
        '';
        name = "postgres-test";
      };
      depends_on = {
        "pg1".condition = "process_healthy";
        "pg2".condition = "process_healthy";
        "pg3".condition = "process_healthy";
      };
    };
}
