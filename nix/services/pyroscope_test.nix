{ pkgs, config, ... }:
{
  services.pyroscope."py1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.pyroscope."py1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.gnugrep
          pkgs.curl
        ];
        text = ''
          curl -sSfN "http://${cfg.httpAddress}:${toString cfg.httpPort}/ready" | grep "ready"
        '';
        name = "pyroscope-test";
      };
      depends_on."py1".condition = "process_healthy";
    };
}
