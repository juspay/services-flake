{ config, ... }: {
  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'ready'
      procs["postgres"]["status"] == "Running"
    )
    machine.succeed("echo 'SELECT version();' | ${config.services.postgres.package}/bin/psql -h 127.0.0.1 -U tester")
  '';
}
