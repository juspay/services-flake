# Contributing

{#new-service}

## New service

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

{#docs}

## Documentation

For contributing to docs, see <https://github.com/flake-parts/community.flake.parts#guidelines-for-writing-docs>

Also see [[documentation]].
