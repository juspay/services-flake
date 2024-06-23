# cargo-doc-live

[cargo-doc-live] is live server version of `cargo doc` ― edit Rust code, and see the docs view in your web browser update automatically.

https://github.com/srid/cargo-doc-live/assets/3998/37378858-dda1-40fb-8f6a-f76dc857a661

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
    projectRoot = ./.;
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
