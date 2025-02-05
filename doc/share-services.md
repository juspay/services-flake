# Share services

Let's say you have two projects: `foo` and `bar`. `foo` defines a service that needs to be used by `bar`. Both `foo` and `bar`, being separate projects, have their own `flake.nix`. In order for `bar` to reuse `foo` service instead of redefining it, `foo` can export `processComposeModules` in its flake `outputs`. `processComposeModules` is not a reserved output; it can be named anything, but the naming is appropriate for this scenario.

Next, we will see basic `flake.nix` for `foo` and `bar`. You can find a more real-world example at <https://github.com/juspay/services-flake/tree/main/example/share-services>.

## foo (Exports its service)

```nix
# foo/flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      flake.processComposeModules.default = ./services.nix;
      perSystem = { pkgs, lib, ... }: {
        process-compose."default" = {
          imports = [
            inputs.services-flake.processComposeModules.default
            inputs.self.processComposeModules.default
          ];
        };
      };
    };
}
```

[[custom-service]] exported by `foo` as `processComposeModules.default`:

```nix
# foo/services.nix
{ pkgs, lib, ... }: {
    options = {
    services.foo = {
      enable = lib.mkEnableOption "Enable foo service";
      package = lib.mkPackageOption pkgs "foo" { };
    };
  };
  config = let cfg = config.services.foo; in
    lib.mkIf cfg.enable {
        settings.processes.foo = {
            command = "${lib.getExe cfg.foo}";
        };
    };
}
```

## bar (Imports foo service)

`bar` wants to reuse `foo`'s service.

```nix
# bar/flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
    foo.url = "<foo-source>";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      flake.processComposeModules.default = ./services.nix;
      perSystem = { pkgs, lib, ... }: {
        process-compose."default" = {
          imports = [
            inputs.services-flake.processComposeModules.default
            inputs.foo.processComposeModules.default
          ];
          services.foo.enable = true;
          
          # The rest of bar's services goes here...
        };
      };
    };
}

```
