---
order: -10
---

# Getting started


## New project

Use the [template flake](https://github.com/juspay/services-flake/blob/main/example/simple/flake.nix) provided by `services-flake`:
```sh
mkdir example && cd ./example
nix flake init -t github:juspay/services-flake
nix run
```

## Existing project

services-flake uses [process-compose-flake](https://community.flake.parts/process-compose-flake) to manage the services. Let's first import the `flake-parts` modules provided by `process-compose-flake` and `services-flake` in your flake:

```nix
{
  # 1. Add the inputs
  inputs.process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  inputs.services-flake.url = "github:juspay/services-flake";
  ...
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # 2. Import the flake-module
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { ... }: {
        # 3. Create the process-compose configuration, importing services-flake
        process-compose."myservices" = {
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
# Inside `perSystem.process-compose."myservices"`
{
  services.redis."r1".enable = true;
}
```

Time to run the service:

```sh
nix run .#myservices
```

## Under the hood

- The `services-flake` module configures [process settings](https://community.flake.parts/process-compose-flake#usage) for a service. In simple terms, it handles stuff like health checks, restart policies, setup scripts, etc. by using the easy to configure APIs provided by `process-compose-flake`.
- The `process-compose-flake` module uses these settings to generate `packages.${system}.myservices`[^how-default] (`nix run .#myservices` above, [runs](https://nixos.asia/en/nix-first#run) this package by default), which runs [process-compose](https://github.com/F1bonacc1/process-compose) with the generated YAML configuration[^sample-config].

[^how-default]: `myservices` is the name of the process group that is derived from `process-compose.<name>` in `perSystem.process-compose`.

[^sample-config]: See the example configuration from the [getting started](https://f1bonacc1.github.io/process-compose/intro/) section of the process-compose docs.

## Examples

- In [Nammayatri](https://github.com/nammayatri/nammayatri), services-flakes is used to run the local services stack (which used to be run with docker-compose). Read about it [in this blog post](https://nixos.asia/en/blog/replacing-docker-compose).
