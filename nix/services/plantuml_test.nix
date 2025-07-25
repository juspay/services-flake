{ pkgs, ... }:
let
  host = "127.0.0.1";
  port = 8080;
in
{
  services.plantuml."plantuml1" = {
    enable = true;
    inherit host port;
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        curl http://${host}:${toString port}
      '';
      name = "plantuml-test";
    };
    depends_on."plantuml1".condition = "process_healthy";
  };
}
