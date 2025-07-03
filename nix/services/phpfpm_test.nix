{ pkgs, config, ... }: {
  services.phpfpm."phpfpm1" = {
    enable = true;
    listen = "phpfpm.sock";
    extraConfig = {
      "pm" = "ondemand";
      "pm.max_children" = 1;
    };
    phpOptions = ''
      date.timezone = "CET"
    '';
    phpEnv = {
      TMPDIR = "/tmp";
    };
    globalSettings = {
      "log_level" = "debug";
    };
  };

  services.phpfpm."phpfpm2" = {
    enable = true;
    listen = 9000;
    extraConfig = {
      "pm" = "ondemand";
      "pm.max_children" = 1;
    };
  };

  settings.processes.test =
    let
      cfg = config.services.phpfpm."phpfpm1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.fcgi ];
        text = ''
          echo "Test connection to phpfpm1 listening on Unix socket"
          cgi-fcgi -bind -connect ./data/phpfpm1/phpfpm.sock

          echo "Test connection to phpfpm2 listening on port 9000"
          cgi-fcgi -bind -connect 127.0.0.1:9000
        '';
        name = "phpfpm-test";
      };
      depends_on."phpfpm1".condition = "process_healthy";
      depends_on."phpfpm2".condition = "process_healthy";
    };
}
