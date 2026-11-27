# PostgreSQL

[PostgreSQL](https://www.postgresql.org/) is a powerful, open source object-relational database
system with over 35 years of active development that has earned it a strong reputation for
reliability, feature robustness, and performance.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1".enable = true;
}
```

## Examples

- Run postgres server initialised with a sample database and graphically interact with it using
  [pgweb](https://github.com/sosedoff/pgweb):
  <https://github.com/juspay/services-flake/tree/main/example/simple>

## Guide

{#init}

### Creating users & tables

Assuming your initial schema is defined in `./scripts/db.sql`:

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1" = {
    enable = true;
    # you can also directly reference file also
    initialScript.before = pkgs.writeText "init.sql" ''
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

### Enable the system_stats extension

Add `system_stats` to the PostgreSQL package with `extensions`, then use
`CREATE EXTENSION` in each database where you need the functions. This example
enables the extension in a newly initialized `mydb` database.

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1" = {
    enable = true;
    extensions = exts: [ exts.system_stats ];
    initialDatabases = [
      {
        name = "mydb";
        schemas = [
          (pkgs.writeText "system-stats.sql" ''
            CREATE EXTENSION system_stats;
          '')
        ];
      }
    ];
  };
}
```

For an existing database, run `CREATE EXTENSION IF NOT EXISTS system_stats;`
while connected to that database as a user with the required privileges.
See the [pgAdmin example](pgadmin.md#visualize-system-statistics) to view the metrics.

## Gotchas

{#socket-path}

### Unix-domain socket path is too long

> [!warning] Only relevant if `socketDir` is set. If not, postgres uses TCP/IP by default.

We already talk about this in the [data directory guide](datadir.md#socket-path). In case of
postgres, you can set `socketDir` while keeping the `dataDir` unchanged.

> [!note] The `socketDir` must be set to a shorter path (less than 100 chars) as a workaround.

```nix
{
  services.postgres."pg1" = {
    enable = true;
    socketDir = "/tmp/pg1";
  };
}
```
