{ pkgs, config, ... }: {
  services.redis-cluster."c1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.redis-cluster."c1";
    in
    {
      command = pkgs.writeShellApplication {
        text = ''
          ${cfg.package}/bin/redis-cli -p 30001 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
          ${cfg.package}/bin/redis-cli -p 30002 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
          ${cfg.package}/bin/redis-cli -p 30003 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
          ${cfg.package}/bin/redis-cli -p 30004 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
          ${cfg.package}/bin/redis-cli -p 30005 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
          ${cfg.package}/bin/redis-cli -p 30006 ping | ${pkgs.gnugrep}/bin/grep -q "PONG"
        '';
        name = "redis-cluster-test";
      };
      depends_on."c1-cluster-create".condition = "process_completed";
    };

}
