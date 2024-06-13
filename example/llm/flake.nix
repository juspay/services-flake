{
  description = "A collection of services enabling the users to perform inference on LLM models";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = import inputs.systems;
    imports = [
      inputs.process-compose-flake.flakeModule
    ];
    perSystem = { self', pkgs, lib, ... }: {
      process-compose."default" = pc: {
        imports = [
          inputs.services-flake.processComposeModules.default
        ];
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
      };
    };
  };
}
