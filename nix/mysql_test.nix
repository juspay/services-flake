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
    let
      cfg = config.services.mysql.m1;
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          echo 'SELECT VERSION();' | MYSQL_PWD="" mysql -u root
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
