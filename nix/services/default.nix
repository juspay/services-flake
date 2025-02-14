let
  inherit (import ../lib.nix) multiService;
  services = [
    ./apache-kafka.nix
    ./clickhouse
    ./elasticsearch.nix
    ./mongodb.nix
    ./mysql
    ./nginx
    ./ollama.nix
    ./postgres
    ./open-webui.nix
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
  ];
in
{
  processComposeModules = {
    imports = (builtins.map (multiService "processComposeModules") services) ++ [ ./devShell.nix ];
  };

  homeModules = {
    imports = (builtins.map (multiService "homeModules") services);
    # imports = lib.pipe services [
    #   (map (multiService "systemd"))
    #   (map (multiService "launchd"))
    # ];
    # imports = (builtins.map (multiService "systemd") services) ++ (builtins.map (multiService "launchd") services);
  };
}
