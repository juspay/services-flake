# Data directory

The `dataDir` of these services tend to take *relative* paths, which are usually relative to the project root. As such, when you run these services using `nix run`, their data files are created relative to whichever directory you are in. If you want these data files to always reside relative to the project directory, instead of using `nix run` consider wrapping the process-compose packages in script, via either [mission-control](https://community.flake.parts/mission-control) module or a [justfile](https://just.systems/). `services-flake` uses the latter.

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

## Gotchas

### Unix-domain socket path is too long

unix socket length is limited to [about 100 chars](https://linux.die.net/man/7/unix). If your data directory is nested too deep, you will have to set `dataDir` option of the service to a shorter path as a workaround.
