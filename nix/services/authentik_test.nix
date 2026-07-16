{ lib
, config
, pkgs
, ...
}:
let
  name = "ak";
  httpPort = 9001;
  ak = config.services.authentik.${name};

  exportPath = config.services.authentik.${name}.blueprints.export.path;
in
{
  services.postgres = ak.services.postgres;

  services.authentik.${name} = {
    enable = true;

    components = pkgs.authentikComponents;

    secretKey = "test";

    postgres = {
      port = 5433;
      user = "authentik";
      name = "authentik";
      password = "authentik";
    };

    server.http.port = 9001;
    worker.http.port = 9002;

    blueprints = {
      export.enable = true;
      imports = [
        ./authentik/test-blueprints/example.yaml
      ];
    };

    settings = {
      logLevel = "info";
    };
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "${name}-test";
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        config.package
      ];
      text = ''
        export PC_SOCKET_PATH="${config.cli.options.unix-socket}"
        # Silence process-compose not finding a config home.
        mkdir -p "$(pwd)/.config/process-compose"
        # shellcheck disable=SC2155
        export XDG_CONFIG_HOME="$(pwd)/.config"

        echo "Checking authentik health endpoints..."
        curl -fsS "http://localhost:${toString httpPort}/-/health/live/"
        curl -fsS "http://localhost:${toString httpPort}/-/health/ready/"
        echo "authentik is up."

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
      '';
    };
    depends_on.${name}.condition = "process_healthy";
  };
}
