{
  inputs = {
    cfp.url = "github:flake-parts/community.flake.parts";
    nixpkgs.follows = "cfp/nixpkgs";
    flake-parts.follows = "cfp/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.cfp.flakeModules.default
      ];
      perSystem = {
        flake-parts-docs = {
          enable = true;
          modules."nixos-flake" = {
            path = ./.;
            pathString = "./.";
          };
        };
      };
    };
}
