{ pkgs, config, ... }: {
  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };
  testScript = 
  let
    psql = "${config.services.postgres.package}/bin/psql";
  in
  ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'ready'
      procs["postgres"]["status"] == "Running"
    )
    machine.succeed("echo 'SELECT version();' | ${config.services.postgres.package}/bin/psql -h 127.0.0.1 -U tester")
    machine.succeed("echo 'SHOW hba_file;' | ${psql} -h 127.0.0.1 -U tester | ${pkgs.gawk}/bin/awk 'NR==3' | ${pkgs.gnugrep}/bin/grep '^ /nix/store'")
  '';
}
