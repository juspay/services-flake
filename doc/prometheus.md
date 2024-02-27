# Prometheus

Prometheus is a systems and service monitoring system. It collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts when specified conditions are observed.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.prometheus."pro1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#scrape-configs}
### Adding Scrape Configs

`scrape_configs`, controls what resources Prometheus monitor.

Since Prometheus also exposes data about itself as an HTTP endpoint it can scrape and monitor its own health. In the [default example configuration](https://github.com/prometheus/prometheus/blob/3f686cad8bee405229b2532584ef181ce9f6a8b3/documentation/examples/prometheus.yml) there is a single job, called prometheus.

To add `scrape_configs`, we can use the following config:

```nix
{
  services.prometheus."pro1" = {
    enable = true;
    # scrape prometheus
    extraConfig = {
      scrape_configs = [{
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
        }];
      }];
    };
  };
}
```
