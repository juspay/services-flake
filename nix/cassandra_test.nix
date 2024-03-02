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
          nodetool -Dcom.sun.jndi.rmiURLParsing=legacy status
          echo 'show version;' | cqlsh
        '';
        name = "cassandra-test";
      };
      depends_on."cass1".condition = "process_healthy";
    };
}
