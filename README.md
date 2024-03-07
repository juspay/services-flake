[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://nixos.zulipchat.com/#narrow/stream/414011-services-flake)

# services-flake

Declarative, composable, and reproducible services for Nix development environment, as a [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) module (based on [flake-parts](https://flake.parts)). Enabling users to have NixOS-like service on MacOS and Linux.

![Demo](./doc/demo.gif)

## Motivation

With `services-flake`, we aim to solve the following problems:

- Run external services like databases, Redis, etc. natively across platforms.
- Enable users to configure multiple instances of these external services.
- Provide project-specific service configuration and data isolation.

## Getting Started

See <https://community.flake.parts/services-flake/start>

## Services available

See the list [here](nix/default.nix).

## A note on process working directory

The `dataDir` of these services tend to take *relative* paths, which are usually relative to the project root. As such, when you run these services using `nix run`, their data files are created relative to whichever directory you are in. If you want these data files to always reside relative to the project directory, instead of using `nix run` consider wrapping the process-compose packages in script, via either [mission-control](https://community.flake.parts/mission-control) module or a [justfile](https://just.systems/). The example uses the latter.

## Discussions

To discuss the project, please [join our Zulip](https://nixos.zulipchat.com/#narrow/stream/414011-services-flake).

## Contributing & Development

See <https://community.flake.parts/services-flake/contributing>

## Credits

Thanks to [the devenv project](https://github.com/cachix/devenv/tree/main/src/modules/services) on which much of our services implementation is based on.

## FAQ

### Why not re-use devenv service modules?

This is currently not possible (nor prioritized by the devenv project), which is why we must create our own services. See <https://github.com/cachix/devenv/issues/75>
