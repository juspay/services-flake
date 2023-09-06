{ pkgs, config, ... }: {
  services.zookeeper."z1".enable = true;
  services.apache-kafka."k1".enable = true;
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.bash config.services.apache-kafka.k1.package ];
        text = ''
          bash kafka-topics.sh --list --bootstrap-server localhost:9092 
        '';
        name = "kafka-test";
      };
      depends_on."k1".condition = "process_healthy";
    };
}
