# OpenObserve

[OpenObserve](https://openobserve.ai) is an observability platform for logs, metrics and traces. It
ships with a web UI, and stores data on local disk in single-node mode.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.openobserve."oo1".enable = true;
}
```

The web UI is then served at <http://127.0.0.1:5080>, and the ingestion and query APIs live under
the same address. Log in with:

|          |                            |
| -------- | -------------------------- |
| Email    | `admin@services-flake.com` |
| Password | `Admin1!@`                 |

{#tips}

## Tips & Tricks

{#credentials}

### Changing the root user

OpenObserve refuses to start without root credentials, so this service supplies the defaults above.
Override them — or set any other
[`ZO_*` variable](https://openobserve.ai/docs/environment-variables/) — through `extraEnvironment`,
which is merged after the module's own defaults:

```nix
{
  services.openobserve."oo1" = {
    enable = true;
    extraEnvironment = {
      ZO_ROOT_USER_EMAIL = "me@example.com";
      ZO_ROOT_USER_PASSWORD = "Somethingelse#456";
    };
  };
}
```

The email must match OpenObserve's address pattern. If it doesn't — or if either variable is unset —
the process panics on startup with a message naming both.

{#telemetry}

### Telemetry

OpenObserve reports anonymous usage data by default. This service disables it. To turn it back on:

```nix
{
  services.openobserve."oo1" = {
    enable = true;
    extraEnvironment.ZO_TELEMETRY = "true";
  };
}
```

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/openobserve_test.nix>
