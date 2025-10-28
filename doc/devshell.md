# DevShell

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

