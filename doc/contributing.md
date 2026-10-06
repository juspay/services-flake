---
order: -9
---

# Contributing

{#devshell}

## Development Shell

A Nix dev shell is available, providing `just`, `nixd`, and the tooling wired up as pre-commit hooks
([treefmt](https://treefmt.com/) with `nixfmt` and `prettier`, plus `commitizen`). To enter the dev
shell, run:

```sh
nix develop ./dev
```

An `.envrc` is also provided, so it is recommended to use `direnv` to automatically enter the dev
shell when you `cd` into the project directory. See [this tutorial](https://nixos.asia/en/direnv).

{#new-service}

## Adding a new service

The project repository is structure to make addition of new services easy. Here's how to add a new
service:

> [!info] See <https://github.com/cachix/devenv/tree/main/src/modules/services> for inspiration.
>
> If you don't find a new service there, see
> <https://github.com/NixOS/nixpkgs/tree/master/nixos/modules/services>.

- Create a new file `./nix/services/<service-name>.nix` file (see
  [./nix/services/redis.nix](https://github.com/juspay/services-flake/blob/main/nix/services/redis.nix)
  for inspiration)
- Add the service to the list in
  [./nix/services/default.nix](https://github.com/juspay/services-flake/blob/main/nix/services/default.nix).
- Create a new test file `./nix/services/<service-name>_test.nix` (see
  [./nix/services/redis_test.nix](https://github.com/juspay/services-flake/blob/main/nix/services/redis_test.nix)).
- Add the test to
  [./test/flake.nix](https://github.com/juspay/services-flake/blob/main/test/flake.nix).

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

It is important to add documentation along with any new services you are contributing. Create a new
file `./doc/<service-name>.md` (see [[clickhouse]] for example) and add the service to the list in
[[services]].

> [!tip] A service that belongs under another one (e.g. a Grafana component) declares its parent
> with a reverse folgezettel link — `#[[grafana]]` — in its own page, and is nested under
> `[[grafana]]` in [[services]]. Without it, the page shows up at the top level of the sidebar.

> [!note] It is recommended to add documentation for non-trivial tasks. For example, grafana
> documentation mentions
> [how to change the default database backend](https://services.nixos.asia/grafana#change-database).

{#docs}

## Documentation

The docs are Markdown files in `./doc`, rendered with [emanote](https://emanote.srid.ca/) by
`doc/flake.nix` (based on [emanote-template](https://github.com/srid/emanote-template)), and
published to <https://services.nixos.asia> by `.github/workflows/pages.yaml`. Emanote's
[authoring guide](https://github.com/srid/emanote/tree/master/docs/authoring) documents the note
syntax — frontmatter, wikilinks, and folgezettel parents.

To preview the docs with live reloading:

```sh
just doc # Or, `cd doc && nix run`
```

To build the static site (this is what gets deployed):

```sh
just doc-static # Or, `nix build ./doc`
```
