{
  description = "A demo of sqlite-web and multiple postgres services";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";

    northwind.url = "github:pthom/northwind_psql";
    northwind.flake = false;
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, lib, ... }: {
        # `process-compose.foo` will add a flake package output called "foo".
        # Therefore, this will add a default package that you can build using
        # `nix build` and run using `nix run`.
        process-compose."simple-example" = { config, ... }:
          let
            dbName = "sample";
          in
          {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            services.postgres."pg1" = {
              enable = true;
              initialDatabases = [
                {
                  name = dbName;
                  schemas = [ "${inputs.northwind}/northwind.sql" ];
                }
              ];
            };

            settings.processes.pgweb =
              let
                pgcfg = config.services.postgres.pg1;
              in
              {
                environment.PGWEB_DATABASE_URL = pgcfg.connectionURI { inherit dbName; };
                command = pkgs.pgweb;
                depends_on."pg1".condition = "process_healthy";
              };
            settings.processes.test = {
              command = pkgs.writeShellApplication {
                name = "pg1-test";
                runtimeInputs = [ config.services.postgres.pg1.package ];
                text = ''
                  echo 'SELECT version();' | psql -h 127.0.0.1 ${dbName}
                '';
              };
              depends_on."pg1".condition = "process_healthy";
            };
          };
        packages.default = self'.packages.simple-example;

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # Add the packages of the enabled services in the devShell
            #
            # For example: `psql` to interact with `postgres` server or `redis-cli` with `redis-server`
            config.process-compose."default".services.outputs.devShell
          ];
          packages = [
            # Add the process-compose app in the devShell
            #
            # In the devShell, run `simple-example` to run the app
            self'.packages.simple-example
          ];
          nativeBuildInputs = [ pkgs.just ];
        };
      };
    };
}
