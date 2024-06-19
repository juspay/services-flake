# Searxng

[Searxng](https://github.com/searxng/searxng) is a free internet metasearch engine which aggregates results from various search services and databases. Users are neither tracked nor profiled.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.searxng."instance-name" = {
    enable = true;
    settings = {
      use_default_settings = true;
      server.port = 1234;
      server.bind_address = "127.0.0.1";
      server.secret_key = "foobar";
    };
  };
}
```
