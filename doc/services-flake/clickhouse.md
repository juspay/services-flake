# Clickhouse

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.clickhouse."clickhouse-1".enable = true;
}
```

## Tips & Tricks

### Change the HTTP default port

Clickhouse has [HTTP Interface](https://clickhouse.com/docs/en/interfaces/http) that is enabled by default on port 8123. To change the default port, use the `extraConfig` option:

```nix
{
  services.clickhouse."clickhouse-1" = {
    enable = true;
    extraConfig = ''
      http_port: 9050
    '';
  };
}
```
