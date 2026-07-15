# Keycloak

[Keycloak](https://www.keycloak.org/) is an open-source identity and access management solution providing single sign-on (SSO), user federation, and support for OpenID Connect, OAuth 2.0 and SAML.

> [!NOTE]
>
> This module runs Keycloak in development mode (`start --optimized` with an embedded database). It is intended for local development and testing, not production.

{#start}

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.keycloak."kc" = {
    enable = true;
    settings.http-port = 8091;

    database.type = "dev-file";

    realms = {
      master = {
        path = ./master.json;
        export = true;
        import = false;
      };
      test = {
        path = ./test.json;
        import = false; # Set that to true once exported.
        export = true;
      };
    };
  };
}
```

Keycloak becomes available at [http://localhost:8091](http://localhost:8091).
The temporary admin user is `admin` with the password set by [`initialAdminPassword`](#admin-password) (`admin` by default).

{#tips}

## Tips & Tricks

{#import-realms}

### Import Realms

A realm listed under `realms` with `import = true` (the default) and a `path` set is imported on start up, provided the realm does not already exist.
The `path` may be relative to the `process-compose` working directory or a Nix store path.

```nix
{
  services.keycloak."kc" = {
    enable = true;

    realms.test = {
      path = ./test.json;
      import = true;
    };
  };
}
```

{#export-realms}

### Export Settings

To export realms when you made changes in the UI, make sure to have set `export = true` on the realms you care about:

```nix
{
  services.keycloak."kc" = {
    enable = true;
    realms.test = {
      path = ./test.json;
      export = true;
    };
  };
}
```

This creates two process-compose processes, both **disabled by default** (they are not run automatically, since exporting requires Keycloak to be stopped):

- `«name»-realm-export-all` — exports every realm with `export = true`.

Run it manually once Keycloak has stopped, e.g. from the process-compose TUI, or:

```bash
# Stop keycloak first then run the export:
process-compose process stop «name»
process-compose process start «name»-realm-export-all
```

Each realm is exported to its `path` when that path is a relative (non-store) location, otherwise to `${config.services.keycloak.«name».dataDir}/realm-export/<realm>.json`. Exports are pretty-printed with `jq` for easy diffing.

You can disable the export processes/scripts globally with `exportRealms = false;`.
