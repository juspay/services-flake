{ pkgs, config, ... }: {
  services.qdrant."qdrant1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.qdrant."qdrant1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "qdrant-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl -f http://${cfg.host}:${toString cfg.httpPort}/healthz
          curl -f http://${cfg.host}:${toString cfg.httpPort}/collections
        '';
      };
      depends_on."qdrant1".condition = "process_healthy";
    };
}
