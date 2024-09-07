{ pkgs, config, ... }:
{
  services.memcached."memcached1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.memcached."memcached1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.gnugrep
          pkgs.netcat
        ];
        text = ''
          echo -e "stats\nquit" | nc 127.0.0.1 11211 | grep "STAT version"
        '';
        name = "memcached-test";
      };
      depends_on."memcached1".condition = "process_healthy";
    };
}
