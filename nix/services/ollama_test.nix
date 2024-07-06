{ pkgs, ... }: {
  services.ollama."ollama1".enable = true;

  # Cannot test auto-loading models yet because that requires internet connection.
  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl http://127.0.0.1:11434
        '';
        name = "ollama-test";
      };
      depends_on."ollama1".condition = "process_healthy";
    };
}
