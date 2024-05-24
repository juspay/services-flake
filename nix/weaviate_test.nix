{ pkgs, config, ... }: {
  services.weaviate."weaviate1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.weaviate."weaviate1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.curl ];
        text = ''
          curl http://localhost:8080/v1/.well-known/live
        '';
        name = "weaviate-test";
      };
      depends_on."weaviate1".condition = "process_healthy";
    };
}
