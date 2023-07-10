{ config, ... }: {
  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialScript.before = "CREATE USER bar;";
    initialScript.after = "CREATE DATABASE foo OWNER bar;";
  };
  testScript = let pg = config.services.postgres.package; in
  ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'ready'
      procs["postgres"]["status"] == "Running"
    )
    machine.succeed("echo 'SELECT version();' | ${pg}/bin/psql -h 127.0.0.1 -U tester")
    # initialScript.before test
    machine.succeed("echo 'SELECT 1 FROM pg_roles WHERE rolname = \'bar\';' | ${pg}/bin/psql -h 127.0.0.1 -U tester | grep -q 1")
    # initialScript.after test
    machine.succeed("echo 'SELECT 1 FROM pg_database WHERE datname = \'foo\';' | ${pg}/bin/psql -h 127.0.0.1 -U tester | grep -q 1")
  '';
}
