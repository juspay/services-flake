{ config, ... }: {
  services.redis-cluster."c1".enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'is_ready' of `c1-cluster-create` instead of `c1-n1` (status of `c1-cluster-create` determines whether the hashslots are assigned). 
      #       This should be easy after https://github.com/juspay/services-flake/issues/32
      procs["c1-n1"]["status"] == "Running"
    )
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30001 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30002 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30003 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30004 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30005 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30006 ping | grep -q 'PONG'")
  '';
}
