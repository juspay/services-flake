{ pkgs, config, ... }: {
  services.ollama."lama1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.ollama."lama1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl ${cfg.host}:${builtins.toString cfg.port} 
        '';
        name = "ollama-test";
      };
      depends_on."lama1-models".condition = "process_completed_successfully";
    };
}
