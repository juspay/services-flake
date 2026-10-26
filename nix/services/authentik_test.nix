{
  config,
  pkgs,
  ...
}:
let
  name = "ak";
  httpPort = 9001;
  ak = config.services.authentik.${name};

  exportPath = ak.blueprints.export.path;

  pg = config.services.postgres."${name}-pg-db";
in
{
  services.postgres = ak.services.postgres;

  services.authentik.${name} = {
    enable = true;

    components = pkgs.authentikComponents;

    secretKey = "test";

    postgres = {
      port = 5433;
      user = "authentik-monkey-system";
      name = "authentik-banana-garbage";
      password = "authentik-banana-pass";
    };

    server.http.port = httpPort;
    worker.http.port = 9002;

    blueprints = {
      export.enable = true;
      imports = [
        ./authentik/test-blueprints/example.yaml
      ];
    };

    logLevel = "info";
  };

  # The server's embedded outpost builds its HTTP client through
  # `rustls-platform-verifier`, which aborts the whole process when it cannot
  # read a system CA bundle. Nix build sandboxes point `SSL_CERT_FILE` at the
  # non-existent `/no-cert-file.crt`.
  settings.environment.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "${name}-test";
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        config.package
        # For `psql`.
        pg.package
      ];
      text = ''
        # `${name}-pg-db` is set up by the authentik service itself, so check
        # that the role and database it created are the ones configured here.
        function check_db() {
          psql_q() {
            psql -h "${ak.postgres.host}" -p "${toString ak.postgres.port}" \
              -d "$1" -tAqX -c "$2"
          }

          assert_eq() {
            if [ "$2" != "$3" ]; then
              echo "!! $1: expected '$3', got '$2'."
              exit 1
            fi
            echo "ok: $1 is '$2'"
          }

          echo "Databases:"
          psql_q postgres \
            "SELECT '  - ' || datname FROM pg_database
              WHERE NOT datistemplate ORDER BY 1"
          echo "Login roles:"
          psql_q postgres \
            "SELECT '  - ' || rolname FROM pg_roles WHERE rolcanlogin ORDER BY 1"

          assert_eq "database" \
            "$(psql_q postgres \
              "SELECT datname FROM pg_database
                WHERE datname = '${ak.postgres.name}'")" \
            "${ak.postgres.name}"

          assert_eq "role" \
            "$(psql_q postgres \
              "SELECT rolname FROM pg_roles
                WHERE rolname = '${ak.postgres.user}'")" \
            "${ak.postgres.user}"

          assert_eq "database owner" \
            "$(psql_q postgres \
              "SELECT pg_get_userbyid(datdba) FROM pg_database
                WHERE datname = '${ak.postgres.name}'")" \
            "${ak.postgres.user}"
        }

        function check_blueprint() {
          export PC_SOCKET_PATH="${config.cli.options.unix-socket}"

          if [ -f "${exportPath}" ]; then
            echo "!! Blueprint file '${exportPath}' should not exist."
            exit 1
          fi

          echo "Check blueprint export."
          process-compose process start "${name}-blueprint-export"

          completed="false"
          for _ in $(seq 1 30); do
            if
              [ "$(
                process-compose process get "${name}-blueprint-export"  \
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

          if [ ! -f "${exportPath}" ]; then
            echo "!! Blueprint file '${exportPath}' did not get exported."
            exit 1
          fi
        }

        check_db
        check_blueprint
      '';
    };

    depends_on.${name}.condition = "process_healthy";
  };
}
