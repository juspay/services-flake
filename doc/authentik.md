# Authentik

[Authentik](https://goauthentik.io/) is an open-source identity provider offering single sign-on
(SSO), user federation and support for OpenID Connect, OAuth 2.0, SAML and more.

> [!NOTE]
>
> This module runs the `migrate`, `worker` and `server` components for local development and
> testing, not for production. Secrets set via `settings`, `secretKey` or `environmentFile` end up
> in the Nix store.

Authentik is not in nixpkgs. You must provide the packages yourself via `components`, taken from the
[`authentik-nix`](https://github.com/nix-community/authentik-nix) flake input. It also needs a
PostgreSQL instance, which this module can configure for you (see below).

{#start}

## Getting Started

```nix
perSystem = {config, inputs', ...}:
let
  ak = config.process-compose."authentik".services.authentik."ak";
in
{
  process-compose."authentik" = {
    # Configure the sidecar postgres process Authentik needs.
    services.postgres = ak.services.postgres;

    # Configure authentik.
    services.authentik."ak" = {
      enable = true;

      components = inputs'.authentik-nix.legacyPackages.authentikComponents;
      secretKey = "insecure-dev-secret";

      server.http.port = 9000;

      postgres = {
        host = "127.0.0.1";
        port = 5433;
        user = "authentik";
        name = "authentik";
        password = "authentik";
      };
    };
  };
}
```

Authentik becomes available at [http://localhost:9000](http://localhost:9000). The bootstrap admin
user is `akadmin` with the e-mail set by `initialAdminEmail` (`admin@example.com` by default) and
the password set by `initialAdminPassword` (`admin` by default).

Anything not covered by a dedicated option can be set through `settings`, which is merged into
Authentik's `authentik/lib/default.yml`.

{#tips}

## Tips & Tricks

{#blueprints}

### Import Blueprints

[Blueprints](https://docs.goauthentik.io/docs/customize/blueprints/) declare Authentik objects
(groups, applications, flows, ...) as YAML. Every blueprint listed in `blueprints.imports` is copied
into Authentik's blueprints directory when the package is built and is auto-applied by the worker on
startup. The paths must be Nix store paths, so a path literal such as `./blueprints/my-app.yaml`
works, but a path relative to the `process-compose` working directory does not.

```nix
{
  services.authentik."ak" = {
    enable = true;

    blueprints.imports = [
      ./blueprints/my-app.yaml
    ];
  };
}
```

{#blueprint-export}

### Export Blueprints

Setting `blueprints.export.enable` adds a disabled `<name>-blueprint-export` process that can be
triggered manually from the process-compose TUI (or with
`process-compose process start <name>-blueprint-export`). It writes the export to
`blueprints.export.path`, which defaults to `<dataDir>/export/blueprint.yaml`.
