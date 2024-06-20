---
short-title: services-flake
template:
  sidebar:
    collapsed: true
emanote:
  folder-folgezettel: false
---

# Running services using `services-flake`

[services-flake][gh] provides declarative, composable, and reproducible services for Nix development environment, as a [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) module (based on [flake-parts](https://flake.parts)). It enables users to have NixOS-like services on MacOS and Linux.

It builds on top of the [process-compose-flake](https://community.flake.parts/process-compose-flake) module which allows running arbitrary processes declared in Nix.

See:

- [[start]]#
- [[examples]]#
- [[services]]#
- [[contributing]]#
- [[guide]]#
- [[custom-service]]#

## Demo

This is how running a service with `services-flake` looks like[^demo]:
:::{.max-w-2xl .h-auto .mx-auto .p-4}
![[demo.gif]]
:::

[^demo]: The commands used in the demo are available [[start]].

[gh]: https://github.com/juspay/services-flake
