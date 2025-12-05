{ pkgs, config, ... }:
{
  services.loki."tp1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.loki."tp1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.gnugrep
          pkgs.curl
        ];
        text = ''
          ROOT_URL="http://${cfg.httpAddress}:${builtins.toString cfg.httpPort}";
          curl -sSfN $ROOT_URL/ready | grep "ready"
        '';
        name = "loki-test";
      };
      depends_on."tp1".condition = "process_healthy";
    };
}
