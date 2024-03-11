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
        process-compose."default" = { config, ... }:
          let
            dbName = "sample";
          in
          {
            imports = [
              inputs.services-flake.processComposeModules.default
              inputs.databases.processComposeModules.default
            ];

            settings.processes.pgweb =
              let
                pgcfg = config.services.postgres.pg1;
              in
              {
                environment.PGWEB_DATABASE_URL = "postgres://$USER@${pgcfg.listen_addresses}:${builtins.toString pgcfg.port}/${dbName}";
                command = pkgs.pgweb;
                depends_on."pg1".condition = "process_healthy";
              };
          };
      };
    };
}
