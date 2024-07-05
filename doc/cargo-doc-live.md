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

### The port for `cargo doc`, the default value is 8008, while you could override it if 8008 is in use for another service.

```nix
{
  services.cargo-doc-live."cargo-doc-live1" = {
    enable = true;
    projectRoot = ./.;
    port = 8080;
  };
}
```

{#crateName}

### The crate to use when opening docs in browser, the crate name will be derived from Cargo.toml.

```nix
{
  services.cargo-doc-live."cargo-doc-live1" = {
    enable = true;
    projectRoot = ./.;
    crateName = "chrono";
  };
}
```
