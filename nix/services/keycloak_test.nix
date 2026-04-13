{ pkgs, config, ... }:
let
  listenAddress = "127.0.0.1";
  adminPort = 8080;
in
{
  services.keycloak."keycloak1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.keycloak."keycloak1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.curl
          pkgs.gnugrep
        ];
        text = ''
          curl -s -o /dev/null -w "%{http_code}" ${listenAddress}:${builtins.toString adminPort} | grep '[2-4]'
        '';
        name = "keycloak-test";
      };
      depends_on."keycloak1".condition = "process_healthy";
    };
}
