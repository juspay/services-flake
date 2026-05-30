{ pkgs, config, ... }:
{
  services.seaweedfs."seaweedfs1" = {
    enable = true;
    filer.enable = true;
    s3.enable = true;
  };

  settings.processes.test =
    let
      cfg = config.services.seaweedfs."seaweedfs1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "seaweedfs-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          # The readiness probe already gates on all endpoints being up, so plain curls suffice.
          curl -fsS -o /dev/null "http://${cfg.host}:${toString cfg.master.port}/cluster/healthz"
          curl -fsS -o /dev/null "http://${cfg.host}:${toString cfg.volume.port}/healthz"
          curl -fsS -o /dev/null "http://${cfg.host}:${toString cfg.filer.port}/"
          curl -fsS -o /dev/null "http://${cfg.host}:${toString cfg.s3.port}/"
        '';
      };
      depends_on."seaweedfs1".condition = "process_healthy";
    };
}
