{ pkgs, config, ... }: {
  services.neo4j."neo4j1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.neo4j."neo4j1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "neo4j-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          # Verify HTTP endpoint is responding
          curl -f http://${cfg.defaultListenAddress}:${toString cfg.httpPort}
        '';
      };
      depends_on."neo4j1".condition = "process_healthy";
    };
}
