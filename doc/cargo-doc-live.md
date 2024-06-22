# cargo-doc-live

[cargo-doc-live] is live server version of `cargo doc`.

{#start}

## Getting started

```nix
# In `perSystem.process-compose.<name>`
{
  services.cargo-doc-live."cargo-doc-live1".enable = true;
}
```

{#port}

### The port for `cargo doc`

```nix
{
  services.cargo-doc-live."cargo-doc-live1" = {
    enable = true;
    port = 8080;
  };
}
```

{#crateName}

### The crate to use when opening docs in browser

```nix
{
  services.cargo-doc-live."cargo-doc-live1" = {
    enable = true;
    crateName = "chrono";
  };
}
```
