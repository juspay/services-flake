let
  inherit (import ../lib.nix) multiService;
in
{
  imports = (builtins.map multiService [
    ./apache-kafka.nix
    ./azurite.nix
    ./clickhouse
    ./elasticsearch.nix
    ./mongodb.nix
    ./mysql
    ./nginx
    ./ollama.nix
    ./postgres
    ./open-webui.nix
    ./plantuml.nix
    ./redis-cluster.nix
    ./redis.nix
    ./zookeeper.nix
    ./grafana.nix
    ./memcached.nix
    ./minio.nix
    ./nats-server.nix
    ./prometheus.nix
    ./pgadmin.nix
    ./cassandra.nix
    ./tempo.nix
    ./weaviate.nix
    ./searxng.nix
    ./tika.nix
    ./phpfpm.nix
    ./pubsub-emulator.nix
  ]) ++ [
    ./devshell.nix
  ];

}
