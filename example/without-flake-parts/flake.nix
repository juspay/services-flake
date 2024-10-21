{
  description = "A demo of services-flake usage without flake-parts";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system: (
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          redis = (import inputs.process-compose-flake.lib { inherit pkgs; }).makeProcessCompose {
            modules = [
              inputs.services-flake.processComposeModules.default
              {
                services.redis."r1".enable = true;
              }
            ];
          };
        }
      ));
    };
}
