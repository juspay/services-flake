# Cassandra

[Cassandra] is a free and open-source, distributed, wide-column store, NoSQL database management system designed to handle large amounts of data across many commodity servers, providing high availability with no single point of failure.

[Cassandra]: https://cassandra.apache.org/_/index.html

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.cassandra."cass1".enable = true;
}
```

{#tips}
## Tips & Tricks

{#change-port}
### Change the default port

By default, the Cassandra server is started on port `9042`. To change the port, we can use the following config:

```nix
{
  services.cassandra."cass1" = {
    enable = true;
    nativeTransportPort = 9043;
  };
}
```
