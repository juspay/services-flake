# Grafana Alloy

[Grafana Alloy](https://grafana.com/docs/alloy/) is an OpenTelemetry Collector distribution with
programmable pipelines, used to collect, process, and forward logs, metrics, traces, and profiles.

## Getting Started

Alloy will not start without a configuration, so `configFile` is required. It is configured with its
own [River-like configuration language](https://grafana.com/docs/alloy/latest/configure/), not YAML.
Point `configFile` at a `.alloy` file — either an external path (`./config.alloy`) or one built
inline with `pkgs.writeText`:

```nix
# In `perSystem.process-compose.<name>`
{ pkgs, ... }:
{
  services.alloy."alloy1" = {
    enable = true;
    configFile = pkgs.writeText "config.alloy" ''
      livedebugging {
        enabled = true
      }
    '';
  };
}
```

Alloy's HTTP UI and API are then served at <http://127.0.0.1:12345>.

{#options}

## Address, port, and extra flags

You can change the HTTP bind address/port and pass extra `alloy run` flags:

```nix
{ pkgs, ... }:
{
  services.alloy."alloy1" = {
    enable = true;
    configFile = pkgs.writeText "config.alloy" ''
      livedebugging {
        enabled = true
      }
    '';
    listenAddress = "0.0.0.0";
    port = 12345;
    extraFlags = [ "--stability.level=experimental" ];
  };
}
```

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/alloy_test.nix>
