# Grafana Loki

[Grafana Loki](https://grafana.com/docs/loki/latest/) is a log aggregation system designed to store and query logs from all your applications and infrastructure.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.loki."tp1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#usage-with-grafana}
### Usage with Grafana

To add loki as a datasource to #[[grafana]], we can use the following config:

```nix
{
  services.loki.tp1.enable = true;
  services.grafana.gf1 = {
    enable = true;
    datasources = with config.services.loki.tp1; [{
      name = "Loki";
      type = "loki";
      access = "proxy";
      url = "http://${httpAddress}:${builtins.toString httpPort}";
    }];
  };
  settings.processes."gf1".depends_on."tp1".condition = "process_healthy";
}
```
