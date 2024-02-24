---
order: -10
---

# Development

{#dev-shell}

## DevShell

Two ways to enter the development environment:

- [Direnv + nix-direnv](https://nixos.asia/en/direnv) (recommended)
- `nix develop .#dev`

{#add-service}

## Adding a new service

- Create a new file `./nix/<service-name>.nix` file (see [./nix/redis.nix](https://github.com/juspay/services-flake/blob/main/nix/redis.nix) for inspiration)
- Add the service to the list in [./nix/default.nix](https://github.com/juspay/services-flake/blob/main/nix/default.nix).
- Create a new test file `./nix/<service-name>_test.nix` (see [./nix/redis_test.nix](https://github.com/juspay/services-flake/blob/main/nix/redis_test.nix)).
- Add the test to [./test/flake.nix](https://github.com/juspay/services-flake/blob/main/test/flake.nix).

{#run-service}

## Run the service

```sh
just run <service-name>
```

{#run-tests}

## Run the tests for the service

The previous command will run the services but not the tests. To run the tests, use:

```sh
just test <service-name>
```

or test all services:

```sh
just test-all
```

## Add documentation

See [[documentation]].
