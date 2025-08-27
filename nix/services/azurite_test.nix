{ pkgs, lib, ... }:
let
  listenAddress = "127.0.0.1";
  blobPort = 10000;
  queuePort = 10001;
  tablePort = 10002;
in
{
  services.azurite."azr1" = {
    inherit
      listenAddress
      blobPort
      queuePort
      tablePort
      ;
    enable = true;
  };
  settings.processes.test = {
    # There doesn't seem to be a surefire way to check using cURL or wget if the service is running as the service
    # will return a non 2xx status code if authentication headers are not provided but still be operational.
    command = pkgs.writeShellApplication {
      name = "azurite-test";
      runtimeInputs = [
        pkgs.curl
        pkgs.gnugrep
      ];
      text = ''
        curl -s -o /dev/null -w "%{http_code}" ${listenAddress}:${builtins.toString blobPort} | grep '[2-4]'
        curl -s -o /dev/null -w "%{http_code}" ${listenAddress}:${builtins.toString tablePort} | grep '[2-4]'
        curl -s -o /dev/null -w "%{http_code}" ${listenAddress}:${builtins.toString queuePort} | grep '[2-4]'
      '';
    };
    depends_on."azr1".condition = "process_healthy";
  };
}
