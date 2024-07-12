{ pkgs, ... }:
{
  services.tika."tika1" = {
    enable = true;
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        curl http://127.0.0.1:9998
      '';
      name = "tika-test";
    };
    depends_on."tika1".condition = "process_healthy";
  };
}
