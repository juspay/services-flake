# Weaviate

{#start}

## Getting started

```nix
# In `perSystem.process-compose.<name>`
{
  services.weaviate."weaviate1".enable = true;
}
```

{#tips}

## Tips & Tricks

{#port}

### Use a different port

```nix
{
  services.weaviate."weaviate1" = {
    enable = true;
    port = 8080;
  };
}
```

{#dataDir}

### Use a different data path

```nix
{
  services.weaviate."weaviate1" = {
    enable = true;
    settings = {
      persistence = {
        dataPath = "./data";
      };
    };
  };
}
```
