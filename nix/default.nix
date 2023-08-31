{ pkgs, lib, ... }:
let
  inherit (import ./lib.nix) multiService;
in {
  imports = builtins.map multiService [
    ./apache-kafka.nix
    ./mysql.nix
    ./postgres.nix
    ./redis.nix
    ./redis-cluster.nix
    ./elasticsearch.nix
    ./zookeeper.nix
  ];
}
