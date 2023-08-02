{ config, ... }: {
  services.redis-cluster."c1".enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'is_ready' instead of 'status'
      procs["c1-cluster-create"]["status"] == "Completed"
    )
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30001 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30002 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30003 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30004 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30005 ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis-cluster.c1.package}/bin/redis-cli -p 30006 ping | grep -q 'PONG'")
  '';
}
