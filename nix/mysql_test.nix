{ pkgs, config, ... }: {
  services.mysql.m1.enable = true;
  services.mysql.m1.initialDatabases = [{ name = "test_database"; }];
  services.mysql.m1.ensureUsers = [
    {
      name = "test_database";
      password = "test_database";
      ensurePermissions = { "test_database.*" = "ALL PRIVILEGES"; };
    }
  ];
  services.mysql.m2.enable = true;
  services.mysql.m2.settings.mysqld.port = 3308;
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ config.services.mysql.m1.package pkgs.gnugrep ];
        text = ''
          rows=$(echo "SHOW DATABASES LIKE 'test_database';" | MYSQL_PWD="" mysql -h 127.0.0.1 | wc -l)
          if [ "$rows" -eq 0 ]; then
            echo "Database doesn't exist."
            exit 1
          fi
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -h 127.0.0.1
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3308
        '';
        name = "mysql-test";
      };
      depends_on = {
        m1.condition = "process_healthy";
        m2.condition = "process_healthy";
      };
    };
}
