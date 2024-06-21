# Running local LLM using ollama and open-webui

While `services-flake` is generally used for running services in a *development* project, typically under a source code checkout, you can also write flakes to derive an end-user app which runs a group of services, which then can be run using `nix run` (or installed using `nix profile install`):

```sh
# You can also use `nix profile install` on this URL, and run `services-flake-llm`
nix run "github:juspay/services-flake?dir=example/llm"
```

>[!NOTE]
>This will download about 9GB of data before launching the Web UI. You can choose a different model or no model (see below) to minimize or avoid this delay.

## Default configuration & models

`example/llm` runs two processes ollama and open-webui

- The ollama data is stored under `$HOME/.services-flake/llm/ollama`. You can change this path in `flake.nix` by setting the `dataDir` option.
- A single model ([`deepseek-coder-v2`](https://ollama.com/library/deepseek-coder-v2)) is automatically downloaded. You can modify this in `flake.nix` as well by setting the `models` option. You can also download models in the open-webui UI.
