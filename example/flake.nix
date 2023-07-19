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
          let
            dbName = "sample";
          in
          {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            services.postgres."pg1" = {
              enable = true;
              listen_addresses = "127.0.0.1";
              initialDatabases = [
                {
                  name = dbName;
                  schema = "${inputs.northwind}/northwind.sql";
                }
              ];
            };

            services.postgres."pg2" = {
              enable = true;
              listen_addresses = "127.0.0.1";
              port = 5433;
            };

            settings.processes.pgweb =
              let
                pgcfg = config.services.postgres.pg1;
              in
              {
                environment.PGWEB_DATABASE_URL = "postgres://$USER@${pgcfg.listen_addresses}:${builtins.toString pgcfg.port}/${dbName}";
                command = pkgs.pgweb;
                depends_on."pg1".condition = "process_healthy";
              };

            # Set this attribute and get NixOS VM tests, as a flake check, for free.
            testScript = ''
              # FIXME: pgweb is still pending, but only in VM tests for some reason.
              process_compose.wait_until(lambda procs:
                procs["pg1"]["status"] == "Running"
              )
              machine.succeed("echo 'SELECT version();' | ${config.services.postgres.pg1.package}/bin/psql -h 127.0.0.1 -U tester ${dbName}")
            '';
          };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.just ];
        };
      };
    };
}
