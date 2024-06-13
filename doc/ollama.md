# Ollama

[Ollama](https://github.com/ollama/ollama) enables you to easily run large language models (LLMs) locally. It supports Llama 3, Mistral, Gemma and [many others](https://ollama.com/library).

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.ollama."ollama1".enable = true;
}
```

## Acceleration

By default Ollama uses the CPU for inference. To enable GPU acceleration:

### CUDA

For NVIDIA GPUs.

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

For Radeon GPUs.

```nix
# In `perSystem.process-compose.<name>`
{
  services.ollama."ollama1" = {
    enable = true;
    acceleration = "rocm";
  };
}
```
