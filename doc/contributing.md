---
order: 10
---

# Contributing

{#devshell}
## Development Shell

A Nix dev shell is available, providing `nixpkgs-fmt` and `just`. To enter the dev shell, run:

```sh
nix develop .#dev
```

An `.envrc` is also provided, so it is recommended to use `direnv` to automatically enter the dev shell when you `cd` into the project directory. See [this tutorial](https://nixos.asia/en/direnv).

{#new-service}
## Adding a new service

The project repository is structure to make addition of new services easy. Here's how to add a new service:

> [!info]
> See <https://github.com/cachix/devenv/tree/main/src/modules/services> for inspiration.
> 
> If you don't find a new service there, see <https://github.com/NixOS/nixpkgs/tree/master/nixos/modules/services>.

- Create a new file `./nix/<service-name>.nix` file (see [./nix/redis.nix](https://github.com/juspay/services-flake/blob/main/nix/redis.nix) for inspiration)
- Add the service to the list in [./nix/default.nix](https://github.com/juspay/services-flake/blob/main/nix/default.nix).
- Create a new test file `./nix/<service-name>_test.nix` (see [./nix/redis_test.nix](https://github.com/juspay/services-flake/blob/main/nix/redis_test.nix)).
- Add the test to [./test/flake.nix](https://github.com/juspay/services-flake/blob/main/test/flake.nix).

{#run-service}
### Run the service

```sh
just run <service-name>
```

{#run-tests}
### Run the tests for the service

The previous command will run the services but not the tests. To run the tests, use:

```sh
just test <service-name>
```

or test all services:

```sh
just test-all
```

{#service-doc}
### Add documentation for the new service

It is important to add documentation along with any new services you are contributing. Create a new file `./doc/<service-name>.md` (see [[clickhouse]] for example) and add the service to the list in [[services]].

> [!note]
> It is recommended to add documentation for non-trivial tasks. For example, grafana documentation mentions [how to change the default database backend](https://community.flake.parts/services-flake/grafana#change-database).



{#docs}
## Documentation

For contributing to docs, see <https://github.com/flake-parts/community.flake.parts#guidelines-for-writing-docs>

We use [emanote](https://emanote.srid.ca/) to render our documentation. The source files are in the `doc` directory. To run the docs, use:

```sh
just doc # Or, `cd doc && nix run`
```

