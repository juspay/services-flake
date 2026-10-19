{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.rustfs.rsfs;
  name = "rsfs";
  exportPath = config.services.rustfs.${name}.iam.export.path;

  defaultCredentials = pkgs.writeText "rustfs-credentials" ''
    RUSTFS_ACCESS_KEY=rustfsadmin
    RUSTFS_SECRET_KEY=rustfsadmin
  '';
in
{
  services.rustfs."rsfs" = {
    enable = true;

    buckets = [
      "test-a"
      "test-b"
    ];

    iam.import.path = ./rustfs/test/iam-export;
    iam.export.enable = true;

    credentialsFile = defaultCredentials;
  };

  settings.processes.${name}.environment = {
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
        pkgs.jq
      ];

      text = ''
        set -eu
        echo "Checking if rustfs console is up."
        curl -fsS "http://${cfg.server.host}:${lib.toString cfg.console.port}/rustfs/console" >/dev/null
        echo "Rustfs console is up."

        echo "Check buckets."
        # shellcheck disable=SC1091
        source "${cfg.credentialsFile}"
        export AWS_ACCESS_KEY_ID="$RUSTFS_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$RUSTFS_SECRET_KEY"
        export AWS_DEFAULT_REGION="${cfg.region}"

        endpoint="${cfg.server.host}:${lib.toString cfg.server.port}"
        out=$(aws --endpoint-url "http://$endpoint" s3api list-buckets --query 'Buckets[].Name' --output text)
        for b in ${lib.escapeShellArgs cfg.buckets}; do
          if ! grep -qw "$b" <<<"$out"; then
            echo "!! Bucket '$b' not listed."
            exit 1
          fi
        done
        echo "All buckets created."

        export PC_SOCKET_PATH="${config.cli.options.unix-socket}"

        if ! process-compose process logs "${name}-provision" |
          grep -q "Provision: Importing IAM from zipping"; then
          echo "Import did not run"
          exit 1
        fi

        echo "Check export."
        process-compose process start "${name}-iam-export"

        completed="false"
        for _ in $(seq 1 30); do
          if
            [ "$(
              process-compose process get "${name}-iam-export"  \
                -o json |
                jq -r ".[0].status"
            )" = "Completed" ]
          then
            completed="true"
            break
          fi

          sleep 2
        done

        if [ "$completed" != "true" ]; then
          echo "!! Blueprint export did not complete in time."
          exit 1
        fi

        # shellcheck disable=SC2010
        if [ ! -d "${exportPath}/iam-assets" ]; then
          echo "!! Export dir '${exportPath}' did not get created."
          ls "${exportPath}"
          exit 1
        fi
      '';
    };
    depends_on."rsfs".condition = "process_healthy";
    depends_on."rsfs-provision".condition = "process_completed";
  };
}
