{ pkgs, config, ... }: {
  services.redis."redis1".enable = true;

  services.redis."redis2" = { config, ... }: {
    enable = true;
    port = 0;
    unixSocket = "./redis.sock";
  };

  settings.processes.test =
    let
      cfg = config.services.redis."redis1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep ];
        text = ''
          echo  "Ping from redis1"
          redis-cli ping | grep "PONG"

          echo "Test connection to redis2 listening on Unix socket"
          echo "Ping from redis2"

          redis-cli -s ./data/redis2/redis.sock ping | grep "PONG"
        '';
        name = "redis-test";
      };
      depends_on."redis1".condition = "process_healthy";
      depends_on."redis2".condition = "process_healthy";
    };
}
