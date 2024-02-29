{ pkgs, config, ... }: {
  services.cassandra."cass1".enable = true;

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
