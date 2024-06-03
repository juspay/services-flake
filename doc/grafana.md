# Grafana

[Grafana open source](https://grafana.com/docs/grafana/latest/)[^broken-on-darwin] is open source visualization and analytics software. It allows you to query, visualize, alert on, and explore your metrics, logs, and traces no matter where they are stored. It provides you with tools to turn your time-series database (TSDB) data into insightful graphs and visualizations.

[^broken-on-darwin]: Grafana is broken on Darwin since `11.0.0` (<https://github.com/NixOS/nixpkgs/pull/311701>). Also see the issue to track the fix: <https://github.com/NixOS/nixpkgs/issues/316954>

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.grafana."gf1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#change-database}
### Changing Grafana database

By default, Grafana stores data in the `sqlite3` [database](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#database). It also supports `mysql` and `postgres`.

To change the database to `postgres`, we can use the following config:

```nix
{
  services.postgres.pg1 = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialScript.after = "CREATE USER root SUPERUSER;";
  };
  services.grafana.gf1 = {
    enable = true;
    extraConf.database = with config.services.postgres.pg1; {
      type = "postgres";
      host = "${listen_addresses}:${builtins.toString port}";
      name = "postgres"; # database name
    };
  };
  settings.processes."gf1".depends_on."pg1".condition = "process_healthy";
  };
}
```
