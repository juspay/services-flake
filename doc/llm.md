---
page:
  image: llm.png
---

# Running local LLM using ollama and open-webui

Imagine having the power to run sophisticated AI chatbots and other services right on your local machine, all with a single command and without relying on constant network access (beyond the initial model download).

Typically used for running services in a *development* project under a source code checkout, `services-flake` also allows you to write flakes to derive an end-user app which runs a group of services, which then can be run using `nix run` (or installed using `nix profile install`):

>[!note]
>This will download about 2.4GB of data before launching the Web UI. You can choose a different model or no model (see [below](https://community.flake.parts/services-flake/llm#default-config)) to minimize or avoid this delay.

```sh
# You can also use `nix profile install` on this URL, and run `services-flake-llm`
nix run "github:juspay/services-flake?dir=example/llm"
```

<center>
<blockquote class="twitter-tweet" data-media-max-width="560"><p lang="en" dir="ltr">Want to run your own AI chatbot (like ChatGPT) locally? You can do that with Nix.<br><br>Powered by services-flake (<a href="https://twitter.com/hashtag/NixOS?src=hash&amp;ref_src=twsrc%5Etfw">#NixOS</a>), using <a href="https://twitter.com/OpenWebUI?ref_src=twsrc%5Etfw">@OpenWebUI</a> and <a href="https://twitter.com/ollama?ref_src=twsrc%5Etfw">@ollama</a>. <br><br>See example: <a href="https://t.co/dyItC93Pya">https://t.co/dyItC93Pya</a> <a href="https://t.co/DeDow8bEPw">pic.twitter.com/DeDow8bEPw</a></p>&mdash; NixOS Asia (@nixos_asia) <a href="https://twitter.com/nixos_asia/status/1803065244568244578?ref_src=twsrc%5Etfw">June 18, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
</center>

>[!info]
>The demo uses [`deepseek-coder-v2`](https://ollama.com/library/deepseek-coder-v2), which is 9GB. However, the default has now been changed to a smaller one: [`phi3`].

{#default-config}
## Default configuration & models

`example/llm` runs two processes [[ollama]] and [[open-webui]]

- The ollama data is stored under `$HOME/.services-flake/llm/ollama`. You can change this path in `flake.nix` by setting the `dataDir` option.
- A single model ([`phi3`]) is automatically downloaded. You can modify this in `flake.nix` as well by setting the `models` option. You can also download models in the open-webui UI.

[`phi3`]: https://ollama.com/library/phi3