# Clickhouse

ClickHouse is an open-source column-oriented DBMS (columnar database management system) for online analytical processing (OLAP) that allows users to generate analytical reports using SQL queries in real-time.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.clickhouse."clickhouse-1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#change-port}
### Change the HTTP default port

Clickhouse has [HTTP Interface](https://clickhouse.com/docs/en/interfaces/http) that is enabled by default on port 8123. To change the default port, use the `extraConfig` option:

```nix
{
  services.clickhouse."clickhouse-1" = {
    enable = true;
    extraConfig = ''
      http_port: 9050
    '';
  };
}
```

{#initial-database}
### Initial database schema

To load a database schema, you can use the `initialDatabases` option:

```nix
{
  services.clickhouse."clickhouse-1" = {
    enable = true;
    initialDatabases = [
      {
        name = "sample_db";
        schemas = [ ./test.sql ];
      }
      # or just create the database:
      {
        name = "sample_db_without_schema";
      }
    ];
  };
}
```
