{ pkgs, config, ... }: {
  services.clickhouse."clickhouse" = {
    enable = true;
    extraConfig = ''
      http_port: 9050
    '';
  };

  settings.processes.test =
    let
      cfg = config.services.clickhouse."clickhouse";
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
          '';
        name = "clickhouse-test";
      };
      depends_on."clickhouse".condition = "process_healthy";
    };
}
