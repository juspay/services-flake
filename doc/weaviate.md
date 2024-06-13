# Weaviate

[Weaviate] is an open-source vector database that stores both objects and vectors, allowing for the combination of vector search with structured filtering with the fault tolerance and scalability of a cloud-native database.

[Weaviate]: https://github.com/weaviate/weaviate

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

{#envs}

### Environment variables

To see list of environment variables, see [this link](https://weaviate.io/developers/weaviate/config-refs/env-vars).

```nix
{
  services.weaviate."weaviate1" = {
    enable = true;
    environment = {
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED = true;
      QUERY_DEFAULTS_LIMIT = 100;
      DISABLE_TELEMETRY = true;
      LIMIT_RESOURCES = true;
      ENABLE_MODULES = ["text2vec-openai" "generative-openai"];
    };
  };
}
```

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
    dataDir = "./data";
  };
}
```
