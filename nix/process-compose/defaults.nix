# Default process-compose cli settings
{ pkgs, lib, ... }:
{
  cli = {
    # Disable the process-compose HTTP server
    options.no-server = lib.mkDefault true;
  };
}
