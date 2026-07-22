# RustFS

[Qdrant](https://github.com/qdrant/qdrant) is a vector similarity search engine and database for AI applications.

Authentik is not in nixpkgs. You must provide the packages yourself via [`components`](#components) from the [`authentik-nix`](https://github.com/nix-community/authentik-nix) flake input.
It also needs a PostgreSQL and a Redis instance.

## Getting Started

```nix
perSystem = {config, inputs', ...}:
let
  ak = config.process-compose."authentik".services.authentik.ak;
in
{
  process-compose."authentik" = {
    # Configure the sidecar postgres and a redis processes.
    services.postgres = ak.services.postgres;
    services.redis = ak.services.redis;

    # Configure authentik.
    services.authentik."authentik" = {
      enable = true;

      compponents = inputs.authentik-nix.packages.${system};
      secretKey = "dev-secret";

      settings = {
        listen.http = "0.0.0.0:9000";

        postgresql = {
          host = "127.0.0.1";
          port = 5433;
          user = "authentik";
          name = "authentik";
          password = "authentik";
        };

        redis.host = "127.0.0.1";
        redis.port = 6378;
      };
    };
  };
`
```
