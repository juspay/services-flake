{ pkgs, config, ... }: {
  services.clickhouse."clickhouse1" = {
    enable = true;
    port = 9000;
    extraConfig = ''
      http_port: 9050
    '';
  };
  services.clickhouse."clickhouse2" = {
    enable = true;
    port = 9001;
    extraConfig = ''
      http_port: 9051
    '';
    initialDatabases = [
      {
        name = "sample_db";
        schemas = [ ./test.sql ];
      }
    ];
  };

  # avoid both the processes trying to create `data` directory at the same time
  settings.processes."clickhouse2-init".depends_on."clickhouse1-init".condition = "process_completed_successfully";
  settings.processes.test =
    let
      cfg = config.services.clickhouse."clickhouse1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl ];
        text =
          let
            # Tests based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/clickhouse.nix
            tableDDL = pkgs.writeText "ddl.sql" "CREATE TABLE `demo` (`value` FixedString(10)) engine = MergeTree PARTITION BY value ORDER BY tuple();";
            insertQuery = pkgs.writeText "insert.sql" "INSERT INTO `demo` (`value`) VALUES ('foo');";
            selectQuery = pkgs.writeText "select.sql" "SELECT * from `demo`";
          in
          ''
            clickhouse-client < ${tableDDL}
            clickhouse-client < ${insertQuery}
            clickhouse-client < ${selectQuery} | grep foo

            # Test clickhouse http port
            curl http://localhost:9050 | grep Ok

            # schemas test
            clickhouse-client --host 127.0.0.1 --port 9001 --query "SELECT * FROM sample_db.ride WHERE short_id = 'test_ride';" | grep test_ride
          '';
        name = "clickhouse-test";
      };
      depends_on."clickhouse2".condition = "process_healthy";
    };
}
