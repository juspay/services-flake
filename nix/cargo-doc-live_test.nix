{ pkgs, ... }: {
  services.cargo-doc-live."cargo-doc-live1" = {
    enable = true;
    crateName = "simple";
  };

  settings.processes.test =
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl http://127.0.0.1:8008/simple
        '';
        name = "cargo-doc-live-test";
      };
      depends_on."cargo-doc-live1".condition = "process_healthy";
    };
}
