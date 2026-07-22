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

  settings.processes.rsfs.environment = {
    # The test needs CA certificates.
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "rustfs-test";
      runtimeInputs = [ pkgs.curl ];
      text = ''
        set -eu
        echo "Checking if rustfs is up."
        curl -sfS "http://${cfg.server.host}:${lib.toString cfg.server.port}/health"
        echo "Rustfs is up."

        echo "Checking if rustfs console is up."
        curl -sfS "http://${cfg.server.host}:${lib.toString cfg.console.port}/rustfs/console"
        echo "Rustfs console is up."
      '';
    };
    depends_on."rsfs".condition = "process_healthy";
  };
}
