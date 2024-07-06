{ pkgs, config, ... }: {
  services.elasticsearch."es1".enable = true;
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl 127.0.0.1:9200/_cat/health 
        '';
        name = "elasticsearch-test";
      };
      depends_on."es1".condition = "process_healthy";
    };
}
