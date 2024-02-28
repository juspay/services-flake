{ pkgs, config, ... }: {
  services.prometheus."pro1" = {
    enable = true;
    # scrape prometheus
    extraConfig = {
      scrape_configs = [{
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
        }];
      }];
    };
  };

  settings.processes.test =
    let
      cfg = config.services.prometheus."pro1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.curl pkgs.gnugrep ];
        text = ''
          curl -sS ${cfg.listenAddress}:${builtins.toString cfg.port}/-/healthy
          curl -s -o /dev/null -w "%{http_code}" ${cfg.listenAddress}:${builtins.toString cfg.port}/metrics
        '';
        name = "prometheus-test";
      };
      depends_on."pro1".condition = "process_healthy";
    };
}
