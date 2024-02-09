---
short-title: services-flake
template:
  sidebar:
    collapsed: true
emanote:
  folder-folgezettel: false
---

# Running services using `services-flake`

[services-flake][gh] is a [flake-parts](https://flake.parts/) module providing [NixOS-like services](https://github.com/NixOS/nixpkgs/tree/master/nixos/modules/services) for [Nix flakes](https://nixos.asia/en/flakes), enabling the users to use same configuration for local development across platforms.

It builds on top of the [process-compose-flake](https://community.flake.parts/process-compose-flake) module which allows running arbitrary processes in the devShell environment.

See:
- [[start]]#
- [[services]]#

## Demo

This is how running a service with `services-flake` looks like[^demo]:
:::{.max-w-2xl .h-auto .mx-auto .p-4}
![[demo.gif]]
:::

[^demo]: The commands used in the demo are available in the [getting started](https://github.com/juspay/services-flake#getting-started) section of the `services-flake` README.

[gh]: https://github.com/juspay/services-flake
