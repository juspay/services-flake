{ pkgs, ... }:
{
  services.searxng."searxng1".enable = true;

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        curl http://127.0.0.1:8080
      '';
      name = "searxng-test";
    };
    depends_on."searxng1".condition = "process_healthy";
  };
}
