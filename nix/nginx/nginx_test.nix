{ pkgs, config, ... }: {
  services.nginx."nginx1" = {
    enable = true;
    httpConfig = ''
      server {
        listen 8888;  
        include ../../importedconfig.conf;
      }
    '';
  };

  settings.processes =
    {
      init = {
        command = pkgs.writeShellApplication {
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            cat >importedconfig.conf <<EOL
            location / {
                add_header Content-Type text/plain;
                return 200 'Looks good';
            }
            EOL
          '';
          name = "init";
        };
      };
      test =
        let
          cfg = config.services.nginx."nginx1";
        in
        {
          command = pkgs.writeShellApplication {
            runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl ];
            text = ''
              curl -s  -H "Accept: text/plain" http://127.0.0.1:8888 | grep -q "Looks good"
            '';
            name = "nginx-test";
          };
          depends_on."nginx1".condition = "process_healthy";
        };
    } // { "nginx1".depends_on."init".condition = "process_completed"; };
}
