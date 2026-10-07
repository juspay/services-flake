{ pkgs, lib, ... }:
{
  services.mimir."mi1" = {
    enable = true;
  };

  settings.processes.test = {
    command = lib.getExe' pkgs.coreutils "true";
    depends_on."mi1".condition = "process_healthy";
  };
}
