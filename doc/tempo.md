# Grafana Tempo

[Grafana Tempo](https://grafana.com/docs/tempo/latest/) is an open-source, easy-to-use, and high-scale distributed tracing backend. Tempo lets you search for traces, generate metrics from spans, and link your tracing data with logs and metrics.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.tempo."tp1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#usage-with-grafana}
### Usage with Grafana

To add tempo as a datasource to #[[grafana]], we can use the following config:

```nix
{
  services.tempo.tp1.enable = true;
  services.grafana.gf1 = {
    enable = true;
    datasources = with config.services.tempo.tp1; [{
      name = "Tempo";
      type = "tempo";
      access = "proxy";
      url = "http://${httpAddress}:${builtins.toString httpPort}";
    }];
  };
  settings.processes."gf1".depends_on."tp1".condition = "process_healthy";
}
```
