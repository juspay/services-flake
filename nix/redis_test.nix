{ pkgs, config, ... }: {
  services.redis."redis1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.redis."redis1";
    in
    {
      command = pkgs.writeShellApplication {
        text = ''
          ${cfg.package}/bin/redis-cli ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
        '';
        name = "redis-test";
      };
      depends_on."redis1".condition = "process_healthy";
    };
}
