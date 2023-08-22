{ pkgs, config, ... }: {
  services.redis-cluster."c1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.redis-cluster."c1";
    in
    {
      disabled = true;
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          redis-cli -p 30001 ping | grep -q "PONG"
          redis-cli -p 30002 ping | grep -q "PONG"
          redis-cli -p 30003 ping | grep -q "PONG"
          redis-cli -p 30004 ping | grep -q "PONG"
          redis-cli -p 30005 ping | grep -q "PONG"
          redis-cli -p 30006 ping | grep -q "PONG"
        '';
        name = "redis-cluster-test";
      };
      depends_on."c1-cluster-create".condition = "process_completed";
    };

}
