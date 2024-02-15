{ pkgs, config, ... }: {
  services.mysql.m1 = {
    enable = true;
    initialDatabases = [{ name = "test_database"; }];
    initialScript = ''
      CREATE USER foo IDENTIFIED BY 'password@123';
      CREATE USER bar;
    '';
  };
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
        runtimeInputs = [ config.services.mysql.m1.package pkgs.gnugrep pkgs.coreutils ];
        text = ''
          rows=$(echo "SHOW DATABASES LIKE 'test_database';" | MYSQL_PWD="" mysql -h 127.0.0.1 | wc -l)
          if [ "$rows" -eq 0 ]; then
            echo "Database doesn't exist."
            exit 1
          fi
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -h 127.0.0.1
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3308

          echo "Checking if users foo and bar are present: "
          isFooPresent=$(echo "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'foo');" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | tail -n1)
          isBarPresent=$(echo "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'bar');" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | tail -n1)
          echo "$isFooPresent" | grep 1
          echo "$isBarPresent" | grep 1

        '';
        name = "mysql-test";
      };
      depends_on = {
        m1-configure.condition = "process_completed";
        m2-configure.condition = "process_completed";
      };
    };
}
