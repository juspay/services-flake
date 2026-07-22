{ lib
, config
, pkgs
, ...
}:
let
  cfg = config.services.rustfs.rsfs;
in
{
  services.rustfs."rsfs" = {
    package = pkgs.rustfs;
    enable = true;
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "rustfs-test";
      runtimeInputs = [ pkgs.curl ];
      text = ''
        echo "Checking if rustfs is up."
        curl -sS "http://${cfg.server.host}:${lib.toString cfg.server.port}/health"
        echo "Rustfs is up."
      '';
    };
    depends_on."rsfs".condition = "process_healthy";
  };
}
