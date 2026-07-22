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
        pkgs.gnugrep
        pkgs.awscli2
      ];

      text = ''
        set -eu
        echo "Checking if rustfs is up."
        curl -fsS "http://${cfg.server.host}:${lib.toString cfg.server.port}/health" >/dev/null
        echo "Rustfs is up."

        echo "Checking if rustfs console is up."
        curl -fsS "http://${cfg.server.host}:${lib.toString cfg.console.port}/rustfs/console" >/dev/null
        echo "Rustfs console is up."

        echo "Check buckets."
        export AWS_ACCESS_KEY_ID="${cfg.accessKey}"
        export AWS_SECRET_ACCESS_KEY="${cfg.secretKey}"
        export AWS_DEFAULT_REGION="${cfg.region}"

        endpoint="${cfg.server.host}:${lib.toString cfg.server.port}"
        out=$(aws --endpoint-url "http://$endpoint" s3api list-buckets --query 'Buckets[].Name' --output text)
        for b in ${lib.escapeShellArgs cfg.provision.buckets}; do
          if ! grep -qw "$b" <<<"$out"; then
            echo "!! Bucket '$b' not listed."
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
