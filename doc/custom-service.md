---
page:
  image: multi-instance-hello.png
---

# Custom service

When using `services-flake` you are not just limited to the [[services|builtin services]]. You can also define your own service.

By default, `services-flake` supports multiple instances for each service, allowing you to run several instances of the same service simultaneously. However, you also have the option to create custom single-instance services. In the following sections, we’ll explore how to define custom services of both types.

{#single-instance}
## Single instance service

We will create a `hello` service that will return a greeting message:

```nix
{ config, lib, pkgs, ... }:
{
  options = {
    services.hello = {
      enable = lib.mkEnableOption "Enable hello service";
      package = lib.mkPackageOption pkgs "hello" { };
      message = lib.mkOption {
        type = lib.types.str;
        default = "Hello, world!";
        description = "The message to be displayed";
      };
    };
  };
  config =
    let
      cfg = config.services.hello;
    in
    lib.mkIf cfg.enable {
      settings.processes.hello = {
        command = "${lib.getExe cfg.package} --greeting='${cfg.message}'";
      };
    };
}
```

Let's call this file `hello.nix`.

Now, we can import this service in our flake. In this example, we will configure an existing service, [[ollama]], and our custom service from above:

```nix
{
  description = "A demo of importing a single instance custom service";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, lib, ... }: {
        process-compose."default" = { config, ... }: {
          imports = [
            inputs.services-flake.processComposeModules.default
            ./hello.nix
          ];

          services.ollama."ollama1".enable = true;
          services.hello.enable = true;
        };
      };
    };
}
```

Finally, `nix run`:
![[single-instance-hello.png]]

{#multi-instance}
## Multi-instance service

For this purpose, `services-flake` exports a [multiService](https://github.com/juspay/services-flake/blob/647bff2c44b42529461f60a7fe07851ff93fb600/nix/lib.nix#L1-L34) library function. It aims to provide an interface wherein the user just writes the configuration like they would for a single instance service, and the library takes care of creating multiple instances of the service.

Let's write the same `hello` service as above, in `hello.nix`, but this time as a multi-instance service:

```nix
{ config, lib, name, pkgs, ... }:
{
  options = {
    enable = lib.mkEnableOption "Enable ${name} service";
    package = lib.mkPackageOption pkgs "hello" { };
    message = lib.mkOption {
      type = lib.types.str;
      default = "Hello, world!";
      description = "The message to be displayed";
    };
  };
  config = {
    outputs.settings = {
      processes.${name} = {
        command = "${lib.getExe config.package} --greeting='${config.message}'";
      };
    };
  };
}
```

The primary differences from the single instance service are:

- The module now takes an additional argument `name`, which is the name of the instance of the service.
- We no longer have to write the `config` block, as it is now handled by the library by importing the `outputs.settings` option.
- And we don't have to write `options.services."${name}"`, as that is abstracted away by the library.

Now that we have defined the multi-instance service, we can import it in our flake:

```nix
{
  description = "A demo of importing a multi-instance custom service";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, lib, ... }: {
        process-compose."default" = 
        let
          inherit (inputs.services-flake.lib) multiService;
        in
        {
          imports = [
            inputs.services-flake.processComposeModules.default
            (multiService ./hello.nix)
          ];

          services.ollama."ollama1".enable = true;
          services.hello = {
            hello1 = {
              enable = true;
              message = "Hello, world!";
            };
            hello2 = {
              enable = true;
              message = "Hello, Nix!";
            };
          };
        };
      };
    };
}
```

And finally, `nix run`:
![[multi-instance-hello.png]]

## See also

- [Postgres with replica](https://github.com/nammayatri/nammayatri/blob/main/Backend/nix/services/postgres-with-replica.nix)
- [Passetto (A custom encryption service)](https://github.com/nammayatri/passetto/blob/nixify/process-compose.nix), is [imported](https://github.com/nammayatri/nammayatri/blob/e8032f1fac3581b9062e2469dfc778d2913d3665/Backend/nix/services/nammayatri.nix#L32) and [configured in the Nammayatri flake](https://github.com/nammayatri/nammayatri/blob/e8032f1fac3581b9062e2469dfc778d2913d3665/Backend/nix/services/nammayatri.nix#L285-L297).
