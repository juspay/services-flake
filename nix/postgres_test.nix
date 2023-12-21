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
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          echo 'SELECT version();' | psql -h 127.0.0.1
          echo 'SHOW hba_file;' | psql -h 127.0.0.1 | ${pkgs.gawk}/bin/awk 'NR==3' | grep '^ /nix/store'
        
          # initialScript.before test
          echo "SELECT 1 FROM pg_roles WHERE rolname = 'bar';" | psql -h 127.0.0.1 | grep -q 1

          # initialScript.after test
          echo "SELECT 1 FROM pg_database WHERE datname = 'foo';" | psql -h 127.0.0.1 | grep -q 1
        '';
        name = "postgres-test";
      };
      depends_on."pg1-init".condition = "process_completed_successfully";
    };
}
