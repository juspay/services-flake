{ pkgs, config, ... }: {
  services.apache-kafka."k1" = {
    enable = true;
    port = 9095;
    clusterId = "MkU3OEVBNTcwNTJENDM2Qk";
    formatLogDirs = true;
    settings = {
      "node.id" = 1;
      "process.roles" = "broker,controller";
      "listeners" = [ "PLAINTEXT://127.0.0.1:9095" "CONTROLLER://127.0.0.1:9093" ];
      "controller.quorum.voters" = "1@127.0.0.1:9093";
      "controller.listener.names" = "CONTROLLER";
      "inter.broker.listener.name" = "PLAINTEXT";
      "offsets.topic.replication.factor" = 1;
    };
  };
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.bash config.services.apache-kafka.k1.package ];
        text = ''
          # Create a topic
          kafka-topics.sh --create --bootstrap-server localhost:9095 --partitions 1 \
          --replication-factor 1 --topic testtopic

          # Producer
          echo 'test 1' | kafka-console-producer.sh --bootstrap-server localhost:9095 --topic testtopic

          # Consumer
          kafka-console-consumer.sh --bootstrap-server localhost:9095 --topic testtopic \
          --from-beginning --max-messages 1 | grep -q "test 1"
        '';
        name = "kafka-kraft-test";
      };
      depends_on."k1".condition = "process_healthy";
    };
}
