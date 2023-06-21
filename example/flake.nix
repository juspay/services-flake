{
  description = "A demo of sqlite-web";
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
      perSystem = { self', pkgs, lib, ... }: {
        # This adds a `self.packages.default`
        process-compose."default" = { config, ... }:
          {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            services.postgres = {
              enable = true;
              listen_addresses = "127.0.0.1";
              initialDatabases = [
                { 
                  name = "sample"; 
                  schema = "${inputs.northwind}/northwind.sql";
                } 
              ];
            };

            settings.processes.pgweb = {
              environment.PGWEB_DATABASE_URL = "postgres://srid@127.0.0.1:5432/sample";
              command = pkgs.pgweb;
              depends_on."postgres".condition = "process_started";
            };

            # Set this attribute and get NixOS VM tests, as a flake check, for free.
            testScript = ''
              process_compose.wait_until(lambda procs:
                procs["postgres"]["status"] == "Running"
              )
              machine.succeed("echo 'SELECT version();' | ${config.services.postgres.package}/bin/psql -h 127.0.0.1 -U tester chinook")
            '';
          };
      };
    };
}
