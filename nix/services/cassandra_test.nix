{ pkgs, config, ... }: {
  services.cassandra."cass1" = {
    enable = true;
    package = pkgs.cassandra;
    # Port 7000 is reserved on macOS (used by AirPlay/Bonjour), so use 7001
    storagePort = 7001;
  };

  settings.processes.test =
    let
      cfg = config.services.cassandra."cass1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package ];
        text = ''
          echo "show version;" | cqlsh
          echo "create keyspace test with replication = {'class': 'SimpleStrategy', 'replication_factor': 1};" | cqlsh
          echo "CREATE TABLE test.test_table(id int PRIMARY KEY, name text);" | cqlsh
          echo "insert into test.test_table (id, name) VALUES (1, 'hello');" | cqlsh
          echo "select * from test.test_table;" | cqlsh | grep hello
        '';
        name = "cassandra-test";
      };
      depends_on."cass1".condition = "process_healthy";
    };
}
