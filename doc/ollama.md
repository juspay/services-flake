# Ollama

[Ollama](https://github.com/ollama/ollama) enables you to get up and running with Llama 3, Mistral, Gemma, and other large language models.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.ollama."ollama1".enable = true;
}
```

## Acceleration

By default Ollama uses the CPU for inference. To enable GPU acceleration:

### Cuda

```nix
# In `perSystem.process-compose.<name>`
{
  services.ollama."ollama1" = {
    enable = true;
    acceleration = "cuda";
  };
}
```

### ROCm

```nix
# In `perSystem.process-compose.<name>`
{
  services.ollama."ollama1" = {
    enable = true;
    acceleration = "rocm";
  };
}
```
