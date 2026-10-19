# Keycloak

[Keycloak](https://www.keycloak.org/) is an open-source identity and access management solution
providing single sign-on (SSO), user federation, and support for OpenID Connect, OAuth 2.0 and SAML.

> [!NOTE]
>
> This module runs Keycloak against an embedded development database (`db = "dev-file"` or
> `"dev-mem"`). It is intended for local development and testing, not for production.

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
        export = {
           enable = true; # Export to data folder.
        };
      };
      test = {
        # Uncomment this once the realm has been exported.
        # import = "./test.json";

        export = {
           enable = true;
           path = "./test.json";
        };
      };
    };
  };
}
```

Keycloak becomes available at [http://localhost:8091](http://localhost:8091). The temporary admin
user is the one set by `initialAdminUsername` (`admin` by default), with the password set by
`initialAdminPassword` (also `admin` by default).

{#tips}

## Tips & Tricks

{#import-realms}

### Import Realms

A realm listed under `realms` with `import` set is imported on startup, provided the realm does not
already exist. The `import` path may either be relative to the `process-compose` working directory
or be a Nix store path.

```nix
{
  services.keycloak."kc" = {
    enable = true;

    realms.test = {
      import = ./test.json; # Nix store path. Quote to make it a relative path.
    };
  };
}
```

{#export-realms}

### Export Settings

To export realms after you have made changes in the admin console, enable `export` on the realms you
care about:

```nix
{
  services.keycloak."kc" = {
    enable = true;

    realms.test = {
      export = {
        enable = true;
        path = "./test.json"; # Optional.
      };
    };
  };
}
```

This creates an additional process `«name»-realm-export-all`, which exports every realm with
`export.enable = true`. It is **disabled by default**, because exporting requires Keycloak to be
stopped.

Run it manually once Keycloak has stopped, e.g. from the process-compose TUI, or:

```bash
# Stop Keycloak first, then run the export:
process-compose process stop «name»
process-compose process start «name»-realm-export-all
```

Each realm is exported to its `path` when that path is a relative (non-store) location, otherwise to
`«dataDir»/realm-export/«realm».json`. Exports are pretty-printed with `jq` for easy diffing.

The export process can be disabled globally with `exportRealms = false;`. Note that it is also
unavailable with `database.type = "dev-mem"`, since that database does not survive a shutdown.
