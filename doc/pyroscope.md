# Grafana Pyroscope

[Grafana Pyroscope](https://grafana.com/docs/pyroscope/latest/) is an open-source continuous profiling database that lets you analyse application performance over time and pinpoint code-level bottlenecks.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.pyroscope."py1".enable = true;
}
```
