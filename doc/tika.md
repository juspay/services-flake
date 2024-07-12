# Tika

[Tika](https://tika.apache.org/) is a content analysis toolkit as a service that can detect and extract metadata and
text from over a thousand different file types.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.tika."instance-name" = {
    enable = true;
    port = 9998;
    host = "127.0.0.1";
  };
}
```
