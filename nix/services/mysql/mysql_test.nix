{ pkgs, config, ... }: {
  services.mysql.m1 = {
    enable = true;
    initialDatabases = [{ name = "test_database"; schema = ./test_schemas; }];
    initialScript = ''
      CREATE USER foo IDENTIFIED BY 'password@123';
      CREATE USER bar;
    '';
    ensureUsers = [
      {
        name = "test_database";
        password = "test_database";
        ensurePermissions = { "test_database.*" = "ALL PRIVILEGES"; };
      }
    ];
  };
  services.mysql.m2 =
    { name, ... }:
    {
      enable = true;
      importTimeZones = true;
      socketDir = "/tmp/${name}";
      settings.mysqld.port = 3308;
    };
  services.mysql.m3 = {
    enable = true;
    # Test whether `-` is allowed in a database name. See https://github.com/juspay/services-flake/issues/513
    initialDatabases = [{ name = "test-database"; }];
    importTimeZones = true;
    package = pkgs.mysql80;
    settings.mysqld.port = 3309;
  };
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
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3309 -u root

          echo "Checking if users foo and bar are present: "
          isFooPresent=$(echo "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'foo');" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | tail -n1)
          isBarPresent=$(echo "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'bar');" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | tail -n1)
          echo "$isFooPresent" | grep 1
          echo "$isBarPresent" | grep 1

          echo "Checking whether named time zones are available: "
          tz_names=$(echo 'SELECT COUNT(*) AS tz_names FROM mysql.time_zone_name;' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3309 -u root | tail -n1)
          if [[ "$tz_names" -eq 0 ]]; then
            echo "time_zone_name table is not populated on mysql"
            exit 1
          else
            echo "time_zone_name table is correctly populated with $tz_names rows n mysql"
          fi
          tz_names=$(echo 'SELECT COUNT(*) AS tz_names FROM mysql.time_zone_name;' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3308 -u root | tail -n1)
          if [[ "$tz_names" -eq 0 ]]; then
            echo "time_zone_name table is not populated on mariadb"
            exit 1
          else
            echo "time_zone_name table is correctly populated with $tz_names rows on mariadb"
          fi
          echo "Checking socketDir:"
          socket=$(echo 'SELECT @@GLOBAL.socket' | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | tail -n1)
          m1socket="$(${pkgs.coreutils}/bin/realpath ${config.services.mysql.m1.dataDir + "/mysql.sock"})"
          if [[ "$socket" != "$m1socket" ]]; then
            echo "socket is not in $m1socket"
            exit 1
          else
            echo "socket is in $m1socket"
          fi
          m2socket="$(${pkgs.coreutils}/bin/realpath ${config.services.mysql.m2.socketDir + "/mysql.sock"})"
          socket=$(echo 'SELECT @@GLOBAL.socket' | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3308 -u root | tail -n1)
          if [[ "$socket" != "$m2socket" ]]; then
            echo "socket is not in $m2socket"
            exit 1
          else
            echo "socket is in $m2socket"
          fi
          
          echo "Checking if both foo.sql and bar.sql are executed, ignoring baz.md"
          echo "SELECT * FROM information_schema.tables WHERE table_schema = 'test_database' AND table_name = 'foo' LIMIT 1;" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | grep foo
          echo "SELECT * FROM information_schema.tables WHERE table_schema = 'test_database' AND table_name = 'bar' LIMIT 1;" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root | grep bar
          if [[ -z $(echo "SELECT * FROM information_schema.tables WHERE table_schema = 'test_database' AND table_name = 'baz' LIMIT 1;" | MYSQL_PWD="" mysql -h 127.0.0.1 -u root) ]]; then
            echo "success! baz table not found"
          else
            echo "baz table shoudn't exist"
            exit 1
          fi

          databases_count=$(echo "SHOW DATABASES LIKE 'test-database';" | MYSQL_PWD="" mysql -h 127.0.0.1 -P 3309 -u root | wc -l)
          if [ "$databases_count" -eq 0 ]; then
            echo "test-database doesn't exist in m3"
            exit 1
          fi
        '';
        name = "mysql-test";
      };
      depends_on = {
        m1-configure.condition = "process_completed";
        m2-configure.condition = "process_completed";
        m3-configure.condition = "process_completed";
      };
    };
}
