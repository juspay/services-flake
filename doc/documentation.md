---
order: -10
---

# Documentation

We use [emanote](https://emanote.srid.ca/) to render our documentation. The source files are in the `doc` directory.

## Run the doc server

Enter the [developement environment](https://community.flake.parts/services-flake/development#dev-shell) and run:

```sh
just doc
```

## Add documentation for a new service

Create a new file `./doc/<service-name>.md` file (see [[clickhouse]] for example) and add the service to the list in [[services]].

> [!note]
> It is recommended to add documentation for non-trivial tasks. For example, grafana documentation mentions [how to change the default database backend](https://community.flake.parts/services-flake/grafana#change-database).
