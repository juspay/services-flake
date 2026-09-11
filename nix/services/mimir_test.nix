{ pkgs, config, ... }:
{
  services.mimir."mi1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.mimir."mi1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          pkgs.gnugrep
          pkgs.curl
        ];
        text = ''
          curl -sSfN "http://${cfg.httpAddress}:${toString cfg.httpPort}/ready" | grep "ready"
        '';
        name = "mimir-test";
      };
      depends_on."mi1".condition = "process_healthy";
    };
}
