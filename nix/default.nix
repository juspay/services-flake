{ pkgs, lib, ... }:
let
  inherit (import ./lib.nix) multiService;
in
{
  imports = builtins.map multiService [
    ./apache-kafka.nix
    ./clickhouse
    ./elasticsearch.nix
    ./mysql
    ./nginx.nix
    ./postgres
    ./redis-cluster.nix
    ./redis.nix
    ./zookeeper.nix
    ./grafana.nix
    ./prometheus.nix
    ./pgadmin.nix
    ./cassandra.nix
  ];
}
