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
        # Currently NOOP as a proper test would require a blob to upload which can be addressed at a later date
        text = "";
      };
      depends_on."seaweedfs1".condition = "process_healthy";
    };
}
