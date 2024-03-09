{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    process-compose.integration-test = { config, ... }: {

      # Share services
      imports = [
        ./external-services.nix
        inputs.services-flake.processComposeModules.default
      ];

      # pre-run cleanup
      # TODO: auto-detect the data directory
      preHook = ''
        rm -rf ./data
      '';

      # post-run cleanup
      postHook = ''
        rm -rf ./data
      '';

      settings.processes.integration-test = {
        command = pkgs.writeShellApplication {
          name = "integration-test";

          # Use the CLIs from the package used in the services
          runtimeInputs = with config.services; [
            (postgres.pg1.package)
            (redis.r1.package)
          ];

          # Test if postgres and redis are running
          text = with config.services; ''
            echo 'SELECT version();' | psql -h ${postgres.pg1.listen_addresses}

            redis-cli ping | grep "PONG" 
          '';
        };

        # Wait for postgres and redis to be healthy
        depends_on = {
          "pg1".condition = "process_healthy";
          "r1".condition = "process_healthy";
        };

        # Exit with the exit-code returned by the integration-test process
        availability.exit_on_end = true;
      };
    };
  };
}
