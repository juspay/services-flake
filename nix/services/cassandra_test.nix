{ pkgs, config, ... }: {
  services.cassandra."cass1" = {
    enable = true;
    # support for aarch64-darwin was added in cassandra-4
    # https://github.com/apache/cassandra/blob/a87055d56a33a9b17606f14535f48eb461965b82/CHANGES.txt#L192
    package = pkgs.cassandra_4;
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
