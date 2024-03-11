{
  description = "pgweb frontend for the northwind db in ../northwind flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";

    # TODO: Remove 'share-services' branch before merging to `main`.
    northwind.url = "github:juspay/services-flake/share-services?dir=example/share-services/northwind";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, lib, ... }: {
        process-compose."default" = { config, ... }: {
          imports = [
            inputs.services-flake.processComposeModules.default
            # Importing this brings whatever processes/services the
            # ../northwind/services.nix module exposes, which in our case is a
            # postgresql process loaded with northwind sample database.
            inputs.northwind.processComposeModules.default
          ];

          # Add a pgweb process, that knows how to connect to our northwind db
          settings.processes.pgweb = {
            command = pkgs.pgweb;
            depends_on."northwind".condition = "process_healthy";
            environment.PGWEB_DATABASE_URL =
              let
                inherit (config.services.postgres.northwind)
                  listen_addresses port;
              in
              "postgres://$USER@${listen_addresses}:${builtins.toString port}/sample";
          };
        };
      };
    };
}
