# Azurite

[Azurite](https://github.com/Azure/Azurite) is an open-source emulator that provides a local environment for testing your Azure Blob, Queue Storage, and Table Storage applications.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.azurite."instance-name" = {
    enable = true;
  };
}
```