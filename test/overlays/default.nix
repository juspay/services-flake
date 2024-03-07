{ lib, system, ... }:

let
  isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";
in
lib.optionals isDarwin [
  (import ./pgadmin.nix)
  (import ./grafana.nix)
]
++
[

]
