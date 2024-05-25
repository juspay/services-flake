{ pkgs, config, ... }: {
  services.weaviate."weaviate1" = {
    enable = true;
    envs = {
      # To fix the problem with nix failing to run weaviate in sandbox mode
      CLUSTER_ADVERTISE_ADDR = "127.0.0.1";
    };
  };

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
