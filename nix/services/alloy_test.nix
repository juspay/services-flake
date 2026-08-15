{
  pkgs,
  lib,
  ...
}:
{
  services.alloy."alloy1" = {
    enable = true;
    configFile = pkgs.writeText "config.alloy" ''
      livedebugging {
        enabled = true
      }
    '';
  };

  settings.processes.test = {
    command = lib.getExe' pkgs.coreutils "true";
    depends_on."alloy1".condition = "process_healthy";
  };
}
