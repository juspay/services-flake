{
  description = "A demo of services-flake usage without flake-parts";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = { nixpkgs, process-compose-flake, services-flake, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f rec {
        pkgs = import nixpkgs { inherit system; };
        servicesMod = (import process-compose-flake.lib { inherit pkgs; }).evalModules {
          modules = [
            services-flake.processComposeModules.default
            {
              services.redis."r1".enable = true;
            }
          ];
        };
      });
    in
    {
      packages = forAllSystems ({ servicesMod, ... }: {
        default = servicesMod.config.outputs.package;
      });

      devShells = forAllSystems ({ pkgs, servicesMod }: {
        default = pkgs.mkShell {
          inputsFrom = [
            servicesMod.config.services.outputs.devShell
          ];
        };
      });
    };
}
