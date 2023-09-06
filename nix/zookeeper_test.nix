{ pkgs, config, ... }: {
  services.zookeeper."z1".enable = true;
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ config.services.zookeeper.z1.package pkgs.netcat.nc ];
        text = ''
          echo stat | nc localhost 2181
        '';
        name = "zookeeper-test";
      };
      depends_on."z1".condition = "process_healthy";
    };
}
