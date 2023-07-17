# services-flake

> **Note**
>
> 🚧 Work in Progress

NixOS-like services for Nix flakes, as a [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) module (based on flake-parts).

![](./example/demo.gif)

## Getting Started

TODO

(But see `./test/flake.nix`)

## Services available

- [x] PostgreSQL
- [ ] MySQL
- [x] Redis
- [ ] ...

## Contributing

- If you are adding a *new* service, see https://github.com/cachix/devenv/tree/main/src/modules/services for inspiration.
- When opening a PR, note that we do not have CI yet, so please run `./test.sh` locally on your **NixOS** machine.

## Credits

Thanks to [the devenv project](https://github.com/cachix/devenv/tree/main/src/modules/services) on which much of our services implementation is based on.

## FAQ

### Why not re-use devenv service modules?

This is currently not possible (nor prioritized by the devenv project), which is why we must create our own services. See https://github.com/cachix/devenv/issues/75
