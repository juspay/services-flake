---
page:
  image: llm.png
template:
  toc:
    enable: false
---

# Local AI chatbot

The [`llm` example][source] allows you to run advanced AI chatbots and services on your own computer with just one command. Once you've downloaded the model, you can use it without needing a constant internet connection.

![[llm.png]]

> [!tip] On dev vs app mode
>
> **services-flake** provides two main uses:
> 
> 1. Running services in development projects with source code access.
> 1. Creating end-user *apps* that run multiple services.
> 
> Our example is based on the second use. These *apps* can be launched with `nix run` or installed using `nix profile install`.

{#run}
## Running the app

To run the local AI chatbot and launch the Web UI,

```sh
# You can also use `nix profile install` on this URL, and run `services-flake-llm`
nix run "github:juspay/services-flake?dir=example/llm"
```

Before launching the Web UI, this will download the [`phi3`] model, which is about 2.4GB. To reduce or avoid this delay, you can:

1.  Choose a different model, or
2.  Use no model at all

See further below for more options.

### Demo

<center>
<blockquote class="twitter-tweet" data-media-max-width="560"><p lang="en" dir="ltr">Want to run your own AI chatbot (like ChatGPT) locally? You can do that with Nix.<br><br>Powered by services-flake (<a href="https://twitter.com/hashtag/NixOS?src=hash&amp;ref_src=twsrc%5Etfw">#NixOS</a>), using <a href="https://twitter.com/OpenWebUI?ref_src=twsrc%5Etfw">@OpenWebUI</a> and <a href="https://twitter.com/ollama?ref_src=twsrc%5Etfw">@ollama</a>. <br><br>See example: <a href="https://t.co/dyItC93Pya">https://t.co/dyItC93Pya</a> <a href="https://t.co/DeDow8bEPw">pic.twitter.com/DeDow8bEPw</a></p>&mdash; NixOS Asia (@nixos_asia) <a href="https://twitter.com/nixos_asia/status/1803065244568244578?ref_src=twsrc%5Etfw">June 18, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
</center>

{#default-config}
## Default configuration & models

The [example][source] runs two processes [[ollama]] and [[open-webui]]

Key points:

1.  **Data storage:**
    -   Ollama data is stored in `$HOME/.services-flake/llm/ollama`
    -   To change this location, edit the `dataDir` option in `flake.nix`
2.  **Model management**:
    -   By default, the [`phi3`] model is automatically downloaded
    -   To change or add models: a. Edit the `models` option in `flake.nix` b. Use the open-webui interface to download additional models.

[`phi3`]: https://ollama.com/library/phi3
[source]: https://github.com/juspay/services-flake/tree/main/example/llm