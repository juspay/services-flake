{ pkgs, config, ... }: {
  services.postgres."pg1" = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialScript.before = "CREATE USER bar;";
    initialScript.after = "CREATE DATABASE foo OWNER bar;";
  };
  settings.processes.test = 
  let
    cfg = config.services.postgres."pg1";
  in
  {
    disabled = true;
    command = pkgs.writeShellApplication {
      text = ''
        echo 'SELECT version();' | ${cfg.package}/bin/psql -h 127.0.0.1
        echo 'SHOW hba_file;' | ${cfg.package}/bin/psql -h 127.0.0.1 | ${pkgs.gawk}/bin/awk 'NR==3' | ${pkgs.gnugrep}/bin/grep '^ /nix/store'
        
        # initialScript.before test
        echo "SELECT 1 FROM pg_roles WHERE rolname = 'bar';" | ${cfg.package}/bin/psql -h 127.0.0.1 | ${pkgs.gnugrep}/bin/grep -q 1

        # initialScript.after test
        echo "SELECT 1 FROM pg_database WHERE datname = 'foo';" | ${cfg.package}/bin/psql -h 127.0.0.1 | ${pkgs.gnugrep}/bin/grep -q 1
      '';
      name = "postgres-test";
    };
    depends_on."pg1".condition = "process_healthy";
    availability.exit_on_end = true;
  };
}
