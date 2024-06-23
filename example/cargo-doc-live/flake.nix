{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
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
        process-compose."cargo-doc-live" = _:
          {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            services.cargo-doc-live."cargo-doc-live1" = {
              projectRoot = inputs.self;
              enable = true;
              port = 8009;
            };

            settings.processes.test = {
              command = pkgs.writeShellApplication {
                name = "cargo-doc-live-test";
                runtimeInputs = [ pkgs.curl ];
                text = ''
                  curl http://127.0.0.1:8009/test
                '';
              };
              depends_on."cargo-doc-live1".condition = "process_healthy";
            };
          };
      };
    };
}
