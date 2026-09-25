{ pkgs, config, ... }:
{
  services.openobserve."oo1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.openobserve."oo1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "openobserve-test";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          curl -sSfN "http://${cfg.httpAddress}:${toString cfg.httpPort}/healthz" \
            | jq -e '.status == "ok"'
        '';
      };

      depends_on."oo1".condition = "process_healthy";
    };
}
