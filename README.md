[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://nixos.zulipchat.com/#narrow/stream/414011-services-flake)

# services-flake

`services-flake` provides declarative, composable, and reproducible services for Nix development environment, as a [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) module (based on [flake-parts](https://flake.parts)). Enabling users to have NixOS-like service on MacOS and Linux.

![Demo](./doc/demo.gif)

## Motivation

With `services-flake`, we aim to solve the following problems:

- Run external services like databases, Redis, etc. natively across platforms.
- Enable users to configure multiple instances of these external services.
- Provide project-specific service configuration and data isolation.

Consider a scenario where we are juggling two projects, located at `~/code/foo` and `~/code/bar`. The `foo` project integrates postgres and nginx, while `bar` encompasses postgres, pgAdmin, and kafka. It's crucial that the postgres data remains segregated across these projects. Additionally, the `bar` project is designed to facilitate multiple instances of postgres. Both projects are equipped with a flake app, streamlining the launch of their respective service stacks. Consequently, anyone using a Linux or macOS system can effortlessly clone either project and execute `nix run .#services` to activate the full suite of services without the need for manual configuration.
## Getting Started

See <https://community.flake.parts/services-flake/start>

## Services available

List of supported services is available at https://community.flake.parts/services-flake/services

## Comparison with similar approaches

| | services-flake | [devenv](https://devenv.sh/) |
| --- | --- | --- |
| macOS support | ✔️  | ✔️  |
| Pure Flakes | ✔️  | ❌[^1]  |
| Share services across flakes | ✔️[^2]  | ❌  |
| Services as flake apps | ✔️  | ❌[^3]  |

[^1]: Devenv's flakes integration [requires](https://devenv.sh/guides/using-with-flakes/) you use run the nix shell in impure mode by passing `--impure`. 
[^2]: `services-flake` is built on top of [flake-parts](https://flake.parts/), thus you may share your service and process modules for re-use across flakes, whilst making them general enough for customization based on the module system.
[^3]: `services-flake` produces a flake app that you can run using the Nix command, `nix run`, whereas with devenv you must use devenv's CLI, `devenv up`.


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
