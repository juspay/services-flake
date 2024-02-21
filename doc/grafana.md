# Grafana Open Source

Grafana open source is open source visualization and analytics software. It allows you to query, visualize, alert on, and explore your metrics, logs, and traces no matter where they are stored. It provides you with tools to turn your time-series database (TSDB) data into insightful graphs and visualizations.

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

1. Create `postgres` service.

```nix
services.postgres."pg1" = {
  enable = true;
  listen_addresses = "127.0.0.1";
  port = 5435;
  initialDatabases = [{
    name = "grafana-db";
  }];
  initialScript.after = ''
    CREATE USER gfuser with PASSWORD 'gfpassword' SUPERUSER;
  '';
};
```

2. Create `grafana` service, and change its config to use the `postgres` database.

```nix
services.grafana."gf1" = {
  enable = true;
  http_port = 3001;
  extraConf = {
    database = {
      type = "postgres";
      host = "127.0.0.1:5435";
      name = "grafana-db";
      user = "gfuser";
      password = "gfpassword";
    };
  };
};
```

3. Add a setting to start `grafana` only after `postgres` is running.

```nix
settings.processes."gf1".depends_on."pg1".condition = "process_healthy";
```
