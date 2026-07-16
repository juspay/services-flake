# Authentik

[Authentik](https://goauthentik.io/) is an open-source identity provider offering single sign-on (SSO), user federation and support for OpenID Connect, OAuth 2.0, SAML and more.

> [!NOTE]
>
> This module runs the `migrate`, `worker` and `server` components for local development and testing, not production. Secrets set via `settings`/`secretKey/`environmentFile` end up in the Nix store.

Authentik is not in nixpkgs. You must provide the packages yourself via [`components`](#components) from the [`authentik-nix`](https://github.com/nix-community/authentik-nix) flake input.
It also needs a PostgreSQL and a Redis instance.

{#start}

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
```

Authentik becomes available at [http://localhost:9000](http://localhost:9000).
The bootstrap admin user is `akadmin` with the e-mail set by [`initialAdminEmail`](#admin-email) (`admin@example.com` by default) and the password set by [`initialAdminPassword`](#admin-password) (`admin` by default).

{#tips}

## Tips & Tricks

{#blueprints}

### Import Blueprints

[Blueprints](https://docs.goauthentik.io/docs/customize/blueprints/) declare Authentik objects (groups, applications, flows, ...) as YAML. A blueprint listed under `settings.blueprints` with `import = true` (the default) and a `path` set is copied into the blueprints directory on start up and auto-applied by the worker.
The `path` may be relative to the `process-compose` working directory or a Nix store path.

```nix
{
  services.authentik."ak" = {
    enable = true;

    settings.blueprints.my-app = {
      path = ./blueprints/my-app.yaml;
    };
  };
}
```
