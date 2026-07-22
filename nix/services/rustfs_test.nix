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
    enable = true;
    package = pkgs.rustfs;

    provision = {
      enable = true;
      buckets = [
        "test-a"
        "test-b"
      ];
    };
  };

  settings.processes.rsfs.environment = {
    # The test needs CA certificates.
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "rustfs-test";

      runtimeInputs = [
        pkgs.curl
        pkgs.minio-client
        pkgs.gnugrep
      ];

      text = ''
        set -eu
        echo "Checking if rustfs is up."
        curl -fsS "http://${cfg.server.host}:${lib.toString cfg.server.port}/health"
        echo "Rustfs is up."

        echo "Checking if rustfs console is up."
        curl -fsS "http://${cfg.server.host}:${lib.toString cfg.console.port}/rustfs/console"
        echo "Rustfs console is up."

        echo "Check buckets."
        endpoint="${cfg.server.host}:${lib.toString cfg.server.port}"
        export MC_HOST_rustfs="http://${cfg.accessKey}:${cfg.secretKey}@$endpoint"
        out=$(mc ls rustfs)
        for b in ${lib.escapeShellArgs cfg.provision.buckets}; do
          if echo "$out" | grep -q "$b"; then
            echo "!! Bucket '$b' not listed.";
            exit 1
          fi
        done
        echo "All buckets created."
      '';
    };
    depends_on."rsfs".condition = "process_healthy";
    depends_on."rsfs-provision".condition = "process_completed";
  };
}
