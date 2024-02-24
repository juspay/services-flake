---
order: -10
---

# Documentation

We use [emanote](https://emanote.srid.ca/) to render our documentation. The source files are in the `doc` directory.

{#run-doc}

## Run the doc server

```sh
just doc
```

{#new-service}

## Add documentation for a new service

Create a new file `./doc/<service-name>.md` (see [[clickhouse]] for example) and add the service to the list in [[services]].

> [!note]
> It is recommended to add documentation for non-trivial tasks. For example, grafana documentation mentions [how to change the default database backend](https://community.flake.parts/services-flake/grafana#change-database).
