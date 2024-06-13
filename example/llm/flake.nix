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
      process-compose."default" = {
        imports = [
          inputs.services-flake.processComposeModules.default
        ];
        services.ollama."ollama1" = {
          enable = true;
          models = [ "llama2-uncensored" ];
        };
      };
    };
  };
}
