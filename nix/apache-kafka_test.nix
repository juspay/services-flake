{ pkgs, config, ... }: {
  services.zookeeper."z1".enable = true;
  # To avoid conflicting with `zookeeper_test.nix` in case the tests are run in parallel
  services.zookeeper."z1".port = 2182;
  services.apache-kafka."k1" = {
    enable = true;
    port = 9094;
    settings = {
      # Since the available brokers are only 1
      "offsets.topic.replication.factor" = 1;
      "zookeeper.connect" = [ "localhost:2182" ];
    };
  };
  # kafka should start only after zookeeper is healthy
  settings.processes.k1.depends_on."z1".condition = "process_healthy";
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.bash config.services.apache-kafka.k1.package ];
        text = ''
          # Create a topic
          kafka-topics.sh --create --bootstrap-server localhost:9094 --partitions 1 \
          --replication-factor 1 --topic testtopic

          # Producer
          echo 'test 1' | kafka-console-producer.sh --broker-list localhost:9094 --topic testtopic

          # Consumer
          kafka-console-consumer.sh --bootstrap-server localhost:9094 --topic testtopic \
          --from-beginning --max-messages 1 | grep -q "test 1"
        '';
        name = "kafka-test";
      };
      depends_on."k1".condition = "process_healthy";
    };
}
