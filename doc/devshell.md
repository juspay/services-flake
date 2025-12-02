# DevShell

## Packages of enabled services

`services-flake` uses [mkShell](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell) function to provide a shell with packages of all the enabled services.

```nix
# Inside `perSystem`
{
  process-compose."my-pc" = { ... };
  devShells.default = pkgs.mkShell {
    inputsFrom = [
      config.process-compose."my-pc".services.outputs.devShell
    ];
    # ...
  };
}
```

## process-compose app

Add the [process-compose](https://github.com/F1bonacc1/process-compose) app in the devShell environment and run the app with `my-pc` (example configuration below) instead of `nix run .#my-pc`.

This is useful when the process(es) assume the devShell environment. For example, see [here](https://github.com/nammayatri/nammayatri/blob/5321a1b9f74c9e27b6282c2c835fdd746c9e281a/Backend/nix/services/nammayatri.nix#L75), `cabal run` (instead of `nix run`) is used to start the Nammayatri process when `useCabal` option is `true`. Additionally, avoiding `nix run .#my-pc` on large monorepos saves on eval-time costs in dirty worktree.

> [!NOTE]
> Disallowing `nix run .#my-pc` in your flake requires <https://github.com/Platonic-Systems/process-compose-flake/issues/27>

```nix
{
  perSystem = { self', ... }: {
    process-compose."my-pc" = {
      # ...
    };

    devShells.default = pkgs.mkShell {
      packages = [
        self'.packages."my-pc"
      ];
      # ...
    };
  };
}
```
