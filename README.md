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

## Comparison with other tools

| | services-flake | [devenv services](https://devenv.sh/services/) |
| --- | --- | --- |
| macOS support | ✔️  | ✔️  |
| Pure Flakes | ✔️  | ✖️[^1]  |
| Services as flake apps | ✔️  | ✖️[^3]  |
| Multiple instances of a service | ✔️  | ✖️[^4]  |
| Share services | ✔️  | ✖️[^2]  |
| No coupling | ✔️  | ✖️[^5]  |

Want to compare with other tools? [Let us know](https://github.com/juspay/services-flake/issues).

[^1]: Devenv's flakes integration [requires](https://devenv.sh/guides/using-with-flakes/) you use run the nix shell in impure mode by passing `--impure`. 
[^2]: `services-flake` is built on top of [flake-parts](https://flake.parts/), thus you may share your service and process modules for re-use across flakes (see [example](./example/share-services)), whilst making them general enough for customization based on the module system. With devenv, as far as we can ascertain, you can only share whole devenv configuration as modules. See [here](https://github.com/juspay/services-flake/pull/135#discussion_r1517425295).
[^3]: `services-flake` produces a flake app that you can run using the Nix command (`nix run`) outside of the devShell, whereas with devenv you must use devenv's CLI, `devenv up`, inside of devShell. See [here](https://github.com/juspay/services-flake/pull/135#discussion_r1517213858).
[^4]: `services-flake` allows you to configure multiple instances of the same service, whereas [devenv does not](https://github.com/cachix/devenv/issues/75#issuecomment-1638859874).
[^5]: `service-flake` exposes [`process-compose-flake`](https://github.com/Platonic-Systems/process-compose-flake) modules for each service, which can be reused as long as your project is using `flake-parts`. With devenv, decoupling is not possible (nor [prioritized](https://github.com/cachix/devenv/issues/75#issuecomment-1324914551) in future) unless you buy into the whole devenv ecosystem.


## Service data directory

See <https://community.flake.parts/services-flake/datadir>

## Discussions

To discuss the project, please [join our Zulip](https://nixos.zulipchat.com/#narrow/stream/414011-services-flake).

## Contributing & Development

See <https://community.flake.parts/services-flake/contributing>

## Credits

Thanks to [the devenv project](https://github.com/cachix/devenv/tree/main/src/modules/services), which originally inspired this project to provide the same for Nix flake users.
