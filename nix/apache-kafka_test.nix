{ pkgs, config, ... }: {
  services.zookeeper."z1".enable = true;
  # To avoid conflicting with `zookeeper_test.nix` in case the tests are run in parallel
  services.zookeeper."z1".port = 2182;
  services.apache-kafka."k1".enable = true;
  services.apache-kafka."k1".zookeeper = "localhost:2182";
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
