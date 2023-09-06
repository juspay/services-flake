{ pkgs, config, ... }: {
  services.zookeeper."z1".enable = true;
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.bash config.services.zookeeper.z1.package ];
        text = ''
          bash zkCli.sh -server localhost:2181 get /
        '';
        name = "zookeeper-test";
      };
      depends_on."z1".condition = "process_healthy";
    };
}
