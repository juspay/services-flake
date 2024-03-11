{
  description = "Frontend for the postgres service defined in databases flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";

    # FIXME: don't use relative path
    databases.url = "../databases";
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
            inputs.databases.processComposeModules.default
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
