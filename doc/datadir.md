# Data directory

`dataDir` is a an option present in all the services, allowing users to specify the directory where a given service will store its data files. Essentially, it is to persist the state of the service even when you exit the `process-compose` window.

The `dataDir` of these services tend to take *relative* paths, which are usually relative to the project root. As such, when you run these services using `nix run`, their data files are created relative to whichever directory you are in. If you want these data files to always reside relative to the project directory, instead of using `nix run` consider wrapping the process-compose packages in script, via either [mission-control](https://community.flake.parts/mission-control) module or a [justfile](https://just.systems/). `services-flake` uses the latter.

{#default-structure}
## Default data directory structure

Let's say your project defines the following services:

```nix
{
    # Inside `perSystem.process-compose.<name>`
    services.postgres.pg.enable = true;
    services.redis.rd.enable = true;
}
```

The data directory structure will look like this:

```sh
|-- data
|   |-- pg
|   |-- rd
```

## Reset state

`dataDir` of a service is where the service persists its state. Resetting the state will not only give the service a fresh start but in some cases, like [[clickhouse]] or other database services, it loads the updated schema/database-init-scripts. To reset the state of an instance of a service, `x`, where `x` is declared in your configuration like `services.<name>.x`, follow:
- Close the `process-compose` process
- `rm -rf $PWD/data/x`
- Start the `process-compose` process

## Gotchas

{#socket-path}
### Unix-domain socket path is too long

Some services create unix domain socket files under the data directory. As the unix socket length is limited to [about 100 chars](https://linux.die.net/man/7/unix), if your data directory is nested too deep, you will have to set `dataDir` option of the service to a shorter path as a workaround.
