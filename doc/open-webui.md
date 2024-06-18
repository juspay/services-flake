# Open WebUI

[Open WebUI](https://github.com/open-webui/open-webui) is a user-friendly WebUI for LLMs. It supports various LLM runners, including [[ollama]] and OpenAI-compatible APIs.

See the demo with [[ollama]] backend:
<center>
<blockquote class="twitter-tweet" data-media-max-width="560"><p lang="en" dir="ltr">Want to run your own AI chatbot (like ChatGPT) locally? You can do that with Nix.<br><br>Powered by services-flake (<a href="https://twitter.com/hashtag/NixOS?src=hash&amp;ref_src=twsrc%5Etfw">#NixOS</a>), using <a href="https://twitter.com/OpenWebUI?ref_src=twsrc%5Etfw">@OpenWebUI</a> and <a href="https://twitter.com/ollama?ref_src=twsrc%5Etfw">@ollama</a>. <br><br>See example: <a href="https://t.co/dyItC93Pya">https://t.co/dyItC93Pya</a> <a href="https://t.co/DeDow8bEPw">pic.twitter.com/DeDow8bEPw</a></p>&mdash; NixOS Asia (@nixos_asia) <a href="https://twitter.com/nixos_asia/status/1803065244568244578?ref_src=twsrc%5Etfw">June 18, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
</center>

{#start}
## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.open-webui."open-webui1".enable = true;
}
```

## Examples

{#ollama}
### Open WebUI with ollama backend

```nix
{
  services = {
    # Backend service to perform inference on LLM models
    ollama."ollama1" = {
      enable = true;
      # The models are usually huge, downloading them in every project directory can lead to a lot of duplication
      dataDir = "$HOME/.services-flake/ollama1";
      models = [ "llama2-uncensored" ];
    };
    # Get ChatGPT like UI, but open-source, with Open WebUI
    open-webui."open-webui1" = {
      enable = true;
      environment =
        let
          inherit (pc.config.services.ollama.ollama1) host port;
        in
        {
          OLLAMA_API_BASE_URL = "http://${host}:${toString port}";
          WEBUI_AUTH = "False";
        };
    };
  };
  # Start the Open WebUI service after the Ollama service has finished initializing and loading the models
  settings.processes.open-webui1.depends_on.ollama1-models.condition = "process_completed_successfully";
}
```

See [[ollama]] for more customisation of the backend.

{#browser}
## Open browser on startup

```nix
{
  services.open-webui."open-webui1".enable = true;
  # Open the browser after the Open WebUI service has started
  settings.processes.open-browser = {
    command =
      let
        inherit (pc.config.services.open-webui.open-webui1) host port;
        opener = if pkgs.stdenv.isDarwin then "open" else lib.getExe' pkgs.xdg-utils "xdg-open";
        url = "http://${host}:${toString port}";
      in
      "${opener} ${url}";
    depends_on.open-webui1.condition = "process_healthy";
  };
}
```
