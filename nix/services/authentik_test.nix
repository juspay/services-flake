{
  config,
  pkgs,
  ...
}:
let
  name = "ak";
  httpPort = 9002;
  ak = config.services.authentik.${name};
in
{
  services.postgres = ak.services.postgres;
  services.redis = ak.services.redis;

  services.authentik.${name} = {
    enable = true;

    components = pkgs.authentik-nix;

    secretKey = "test";

    settings = {
      logLevel = "info";

      listen.http = "0.0.0.0:${toString httpPort}";

      postgres = {
        port = 5433;
        user = "authentik";
        name = "authentik";
        password = "authentik";
      };

      redis.port = 6378;

      blueprints.example = {
        path = ./authentik/test-blueprints/example.yaml;
      };
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
