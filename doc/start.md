---
order: -10
---

# Getting started


## New project

Use the [template flake](https://github.com/juspay/services-flake/blob/main/example/flake.nix) provided by `services-flake`:
```sh
mkdir example && cd ./example
nix flake init -t github:juspay/services-flake
nix run
```

## Existing project

services-flake uses [process-compose-flake](https://community.flake.parts/process-compose-flake) to manage the services. Let's first import the `flake-parts` modules provided by `process-compose-flake` and `services-flake` in your flake:
```nix
{
  inputs.process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  inputs.services-flake.url = "github:juspay/services-flake";
  ...
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { ... }: {
        process-compose."default" = {
          imports = [
            inputs.services-flake.processComposeModules.default
          ];
        };
      }
    };
}
```
As an example, let's add the `redis` service to your flake:
```nix
# Inside `perSystem.process-compose.default`
{
  services.redis."r1".enable = true;
}
```

Time to run the service:
```sh
nix run
```

## Under the hood

- The `services-flake` module configures [process settings](https://community.flake.parts/process-compose-flake#usage) for a service. In simple terms, it handles stuff like health checks, restart policies, setup scripts, etc. by using the easy to configure APIs provided by `process-compose-flake`.
- The `process-compose-flake` module uses these settings to generate `packages.${system}.default`[^how-default] (`nix run` above, runs this package by default), which runs [process-compose](https://github.com/F1bonacc1/process-compose) with the generated YAML configuration[^sample-config].

[^how-default]: `default` is the name of the process group that is derived from `process-compose.<name>` in `perSystem.process-compose`.

[^sample-config]: See the example configuration from the [getting started](https://f1bonacc1.github.io/process-compose/intro/) section of the process-compose docs.

## See also

If you are looking to replace docker and use `services-flake` in your dev environment, read about how we accomplished it at [Nammayatri](https://github.com/nammayatri/nammayatri): <https://nixos.asia/en/blog/replacing-docker-compose>
