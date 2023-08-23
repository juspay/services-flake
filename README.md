# services-flake

> **Note**
>
> 🚧 Work in Progress

NixOS-like services for Nix flakes, as a [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) module (based on flake-parts).

![](./doc/demo.gif)

## Getting Started

TODO

(But see `./test/flake.nix`)

## Services available

- [x] PostgreSQL
- [ ] MySQL
- [x] Redis
- [x] Redis Cluster
- [x] Elasticsearch
- [ ] ...

## A note on process working directory

The `dataDir` of these services tend to take *relative* paths, which are usually relative to the project root. As such, when you run these services using `nix run`, their data files are created relative to whichever directory you are in. If you want these data files to always reside relative to the project directory, instead of using `nix run` consider wrapping the process-compose packages in script, via either [mission-control](https://zero-to-flakes.com/mission-control/) module or a [justfile](https://just.systems/). The example uses the latter.

## Contributing

- If you are adding a *new* service, see https://github.com/cachix/devenv/tree/main/src/modules/services for inspiration.
- When opening a PR, note that we do not have CI yet, so please run `nix run nixpkgs#nixci` locally on your **NixOS** machine.
- For contributing to docs, see https://zero-to-flakes.com/about#contributing

## Credits

Thanks to [the devenv project](https://github.com/cachix/devenv/tree/main/src/modules/services) on which much of our services implementation is based on.

## FAQ

### Why not re-use devenv service modules?

This is currently not possible (nor prioritized by the devenv project), which is why we must create our own services. See https://github.com/cachix/devenv/issues/75
