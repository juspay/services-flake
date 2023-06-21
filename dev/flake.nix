{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
      ];
      perSystem = { pkgs, lib, config, ... }: {
        mission-control.scripts = {
          ex = {
            description = "Run example";
            exec = "cd ./example && nix run . --override-input services-flake ..";
          };
          test = {
            description = "Run test";
            exec = "./test.sh";
          };
          fmt = {
            description = "Format the top-level Nix files";
            exec = "${lib.getExe pkgs.nixpkgs-fmt} ./*.nix";
          };
        };
        devShells.default = pkgs.mkShell {
          # cf. https://haskell.flake.page/devshell#composing-devshells
          inputsFrom = [ config.mission-control.devShell ];
        };
      };
    };
}
