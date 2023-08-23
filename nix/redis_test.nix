{ pkgs, config, ... }: {
  services.redis."redis1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.redis."redis1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          redis-cli ping | grep -q "PONG"
        '';
        name = "redis-test";
      };
      depends_on."redis1".condition = "process_healthy";
    };
}
