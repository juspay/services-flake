# Grafana Mimir

[Grafana Mimir](https://grafana.com/docs/mimir/latest/) is an open-source, horizontally scalable,
highly available, multi-tenant time series database that provides long-term storage for Prometheus.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.mimir."mi1".enable = true;
}
```

By default the service runs in monolithic mode (`-target=all`) with filesystem storage under its
[[datadir]].

{#tips}

## Tips & Tricks

{#usage-with-grafana}

### Usage with Grafana

To add mimir as a Prometheus datasource to #[[grafana]], we can use the following config:

```nix
{
  services.mimir.mi1.enable = true;
  services.grafana.gf1 = {
    enable = true;
    datasources = with config.services.mimir.mi1; [{
      name = "Mimir";
      type = "prometheus";
      access = "proxy";
      url = "http://${httpAddress}:${builtins.toString httpPort}/prometheus";
    }];
  };
  settings.processes."gf1".depends_on."mi1".condition = "process_healthy";
}
```
