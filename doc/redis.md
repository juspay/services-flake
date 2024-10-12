# Redis

[Redis](https://redis.io/) is an in-memory data structure store used as a database, cache, and message broker.

## Unix socket

Redis supports the usage of [Unix socket](https://man7.org/linux/man-pages/man2/socket.2.html) to listen to connections. By default, Redis listens to connections over TCP on port `6379`. When using Unix socket, you can decide to either enable listening on both or disable listening on TCP by setting port to `0` (recommended).

```nix
# Inside `process-compose.<name>`
{
  services.redis."r1" = {
    enable = true;
    port = 0;
    # relative paths are relative to the data directory, which is `$PWD/data/r1` by default
    unixSocket = "./redis.sock";
  };
}
```
## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/redis_test.nix>
