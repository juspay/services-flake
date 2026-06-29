{ pkgs, lib, config, ... }:
{
  services.seaweedfs."seaweedfs1" = {
    enable = true;
    filer.enable = true;
    s3.enable = true;
  };

  settings.processes.test = {
    command = lib.getExe' pkgs.coreutils "true";
    depends_on."seaweedfs1".condition = "process_healthy";
  };
}
