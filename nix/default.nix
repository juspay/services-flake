{ pkgs, lib, ... }:
let
  inherit (import ./lib.nix) multiService;
in
{
  imports = builtins.map multiService [
    ./apache-kafka.nix
    ./clickhouse.nix
    ./elasticsearch.nix
    ./mysql.nix
    ./nginx.nix
    ./postgres
    ./redis-cluster.nix
    ./redis.nix
    ./zookeeper.nix
  ];
}
