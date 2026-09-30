{ pkgs, lib, ... }:
{
  services.openobserve."oo1".enable = true;

  settings.processes.test = {
    command = lib.getExe' pkgs.coreutils "true";
    depends_on."oo1".condition = "process_healthy";
  };
}
