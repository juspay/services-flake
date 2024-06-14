# Running local LLM using ollama and open-webui

While `services-flake` is generally used for running services in a *development* project, typically under a source code checkout, you can also write flakes to derive an end-user app which runs a group of services. 

`example/llm` runs two processes ollama and open-webui, while storing the ollama data under `$HOME/.services-flake/ollama`. You can change this path in `flake.nix`.

By default, a single model (`llama2-uncensored`) is downloaded. You can modify this in `flake.nix` as well.
