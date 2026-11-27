# Apache Kafka

[Apache Kafka](https://kafka.apache.org/) is a distributed event streaming platform used by
thousands of companies for high-performance data pipelines, streaming analytics, data integration,
and mission-critical applications.

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/apache-kafka_test.nix>

## Run Kafka in KRaft mode

KRaft uses Kafka's own controllers to manage metadata. A local single-node
setup can run the broker and controller in the same Kafka process without ZooKeeper.
Generate an ID for the cluster with `kafka-storage.sh random-uuid`, then use that
value for `clusterId`.

```nix
# In perSystem.process-compose.<name>
{
  services.apache-kafka.k1 = {
    enable = true;
    clusterId = "MkU3OEVBNTcwNTJENDM2Qk";
    formatLogDirs = true;
    settings = {
      "node.id" = 1;
      "process.roles" = "broker,controller";
      "listeners" = [
        "PLAINTEXT://127.0.0.1:9092"
        "CONTROLLER://127.0.0.1:9093"
      ];
      "controller.quorum.voters" = "1@127.0.0.1:9093";
      "controller.listener.names" = "CONTROLLER";
      "inter.broker.listener.name" = "PLAINTEXT";
      "offsets.topic.replication.factor" = 1;
    };
  };
}
```

Clients connect to the broker on port 9092. Port 9093 is the controller listener.
`formatLogDirs` initializes unformatted Kafka storage. Keep the cluster ID for
subsequent runs using the same data directory.

The [KRaft integration test](https://github.com/juspay/services-flake/blob/main/nix/services/apache-kafka-kraft_test.nix)
shows how to create a topic, publish a message, and consume it.
