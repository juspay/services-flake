# Ollama

[Ollama](https://github.com/ollama/ollama) enables you to easily run large language models (LLMs) locally. It supports Llama 3, Mistral, Gemma and [many others](https://ollama.com/library).

<center>
<blockquote class="twitter-tweet" data-media-max-width="560"><p lang="en" dir="ltr">❄️You can now perform LLM inference with Ollama in services-flake!<a href="https://t.co/rtHIYdnPfb">https://t.co/rtHIYdnPfb</a> <a href="https://t.co/1hBqMyViEm">pic.twitter.com/1hBqMyViEm</a></p>&mdash; NixOS Asia (@nixos_asia) <a href="https://twitter.com/nixos_asia/status/1800855562072322052?ref_src=twsrc%5Etfw">June 12, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
</center>

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

Firstly, allow unfree packages:

```nix
# Inside perSystem = { system, ... }: { ...
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/misc/nixpkgs.nix"
  ];
  nixpkgs = {
    hostPlatform = system;
    # Required for CUDA
    config.allowUnfree = true;
  };
}
```

And then enable CUDA acceleration:

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
