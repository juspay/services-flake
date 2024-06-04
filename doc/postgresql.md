# PostgreSQL

[PostgreSQL](https://www.postgresql.org/) is a powerful, open source object-relational database system with over 35 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1".enable = true;
}
```

## Examples

- Run postgres server initialised with a sample database and graphically interact with it using [pgweb](https://github.com/sosedoff/pgweb): <https://github.com/juspay/services-flake/tree/main/example/simple>

## Guide

{#init}
### Creating users & tables

Assuming your initial schema is defined in `./scripts/db.sql`:

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1" = {
    enable = true;
    initialScript.before = ''
      CREATE USER myuser WITH password 'mypasswd';
    '';
    initialDatabases = [
      {
        name = "mydb";
        schemas = [ ./scripts/db.sql ];
      }
    ];
  };
}
```

## Gotchas

{#socket-path}
### Unix-domain socket path is too long

> [!warning]
> Only relevant if `socketDir` is set. If not, postgres uses TCP/IP by default.

We already talk about this in the [data directory guide](datadir.md#socket-path). In case of postgres, you can set `socketDir` while keeping the `dataDir` unchanged.

>[!note]
> The `socketDir` must be set to a shorter path (less than 100 chars) as a workaround.

```nix
{
  services.postgres."pg1" = {
    enable = true;
    socketDir = "/tmp/pg1";
  };
}
```
