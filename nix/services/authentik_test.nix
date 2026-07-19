{ config
, pkgs
, ...
}:
let
  name = "ak";
  httpPort = 9001;
  ak = config.services.authentik.${name};
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

    blueprints.example = {
      path = ./authentik/test-blueprints/example.yaml;
    };

    settings = {
      logLevel = "info";
    };
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      name = "${name}-test";
      runtimeInputs = [ pkgs.curl ];
      text = ''
        echo "Checking authentik health endpoints..."
        curl -fsS "http://localhost:${toString httpPort}/-/health/live/"
        curl -fsS "http://localhost:${toString httpPort}/-/health/ready/"
        echo "authentik is up."
      '';
    };
    depends_on.${name}.condition = "process_healthy";
  };
}
