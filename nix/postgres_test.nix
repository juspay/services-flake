{ pkgs, config, ... }: {
  services.postgres."pg1" = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialScript.before = "CREATE USER bar;";
    initialScript.after = "CREATE DATABASE foo OWNER bar;";
  };
  testScript =
    let
      cfg = config.services.postgres."pg1";
      psql =
        "${cfg.package}/bin/psql";
    in
    ''
      process_compose.wait_until(lambda procs:
        # TODO: Check for 'ready'
        procs["pg1"]["status"] == "Running"
      )
      machine.succeed("echo 'SELECT version();' | ${psql} -h 127.0.0.1 -U tester")
      machine.succeed("echo 'SHOW hba_file;' | ${psql} -h 127.0.0.1 -U tester | ${pkgs.gawk}/bin/awk 'NR==3' | ${pkgs.gnugrep}/bin/grep '^ /nix/store'")
      # initialScript.before test
      machine.succeed("echo \"SELECT 1 FROM pg_roles WHERE rolname = 'bar';\" | ${psql} -h 127.0.0.1 -U tester | grep -q 1")
      # initialScript.after test
      machine.succeed("echo \"SELECT 1 FROM pg_database WHERE datname = 'foo';\" | ${psql} -h 127.0.0.1 -U tester | grep -q 1")
    '';
}
