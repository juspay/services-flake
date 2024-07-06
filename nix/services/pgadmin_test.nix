{ pkgs, config, ... }: {

  services.pgadmin."pgad1" = {
    enable = true;
    initialEmail = "email@gmail.com";
    initialPassword = "password";
  };

  settings.processes.test =
    let
      cfg = config.services.pgadmin."pgad1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.curl pkgs.gnugrep ];
        text = ''
          curl http://localhost:5050/misc/ping | grep "PING"
        '';
        name = "pgadmin-test";
      };
      depends_on."pgad1".condition = "process_healthy";
    };
}
