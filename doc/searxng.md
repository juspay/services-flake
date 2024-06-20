# Searxng

[Searxng](https://github.com/searxng/searxng) is a free internet metasearch engine which aggregates results from various search services and databases. Users are neither tracked nor profiled.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.searxng."instance-name" = {
    enable = true;
    port = 1234;
    host = "127.0.0.1";
    secret_key = "my-secret-key";
    settings = {
      doi_resolvers."dummy" = "http://example.org";
      default_doi_resolver = "dummy";
    };
  };
}
```
