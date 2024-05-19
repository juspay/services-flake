{
  description = "A demo of grafana with tempo";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "git+file:///Volumes/Code/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, lib, ... }: {
        # `process-compose.foo` will add a flake package output called "foo".
        # Therefore, this will add a default package that you can build using
        # `nix build` and run using `nix run`.
        process-compose."default" = { config, ... }: {
          imports = [
            inputs.services-flake.processComposeModules.default
          ];

          services.tempo."tp1".enable = true;
          services.grafana."gf1" = {
            enable = true;
            datasources = with config.services.tempo.tp1; [{
              name = "Tempo";
              type = "tempo";
              access = "proxy";
              url = "http://${httpAddress}:${builtins.toString httpPort}";
            }];
          };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.just ];
        };
      };
    };
}
