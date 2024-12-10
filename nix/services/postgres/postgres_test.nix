{ pkgs, config, name, ... }: {
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

  # Tests if `pg4-init` fails due to `./bad_test.sql`
  services.postgres."pg4" = {
    enable = true;
    socketDir = "./test/new/socket/path3";
    listen_addresses = "";
    initialDatabases = [
      {
        name = "test-db";
        schemas = [ ./bad_test.sql ];
      }
    ];
  };
  # avoid both the processes trying to create `data` directory at the same time
  settings.processes."pg2-init".depends_on."pg1-init".condition = "process_completed_successfully";
  settings.processes."pg3-init".depends_on."pg2-init".condition = "process_completed_successfully";
  settings.processes."pg4-init".depends_on."pg3-init".condition = "process_completed_successfully";

  settings.processes.test =
    let
      cfg = config.services.postgres."pg1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl pkgs.jq ];
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

          # Test if `pg4-init` fails due to `bad_test.sql`
          #
          # The curl to process-compose server is documented in the swagger URL, http://localhost:8080, but since we are listening on unix socket here, you can use `socat` to temporarily pipe the port `8080` to the `pc-${name}.sock` (`socat TCP-LISTEN:8080,fork UNIX-CONNECT:/path/to/your/socket.sock
 
          # OpenAPI documentation from the swagger URL:
          # /process/logs/{name}/{endOffset}/{limit}
          curl --unix-socket pc-${name}.sock http://localhost/process/logs/pg4-init/30/0 | jq '.logs | contains(["ERROR:  syntax error at or near \"STABLE\""])' | grep "true"
        '';
        name = "postgres-test";
      };
      depends_on = {
        "pg1".condition = "process_healthy";
        "pg2".condition = "process_healthy";
        "pg3".condition = "process_healthy";
        "pg4-init".condition = "process_completed";
      };
    };
}
