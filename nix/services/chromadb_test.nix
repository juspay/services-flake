{ pkgs, config, ... }: {
  services.chromadb."chromadb1" = {
    enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.chromadb."chromadb1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "chromadb-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl -f http://${cfg.host}:${toString cfg.port}/api/v2/heartbeat
        '';
      };
      depends_on."chromadb1".condition = "process_healthy";
    };
}
