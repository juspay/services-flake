{ config, ... }: {
  services.redis."redis1".enable = true;
  services.redis."redis2" = {
    enable = true;
    port = 6380;
  };
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'is_ready' instead of 'status'
      procs["redis1"]["status"] == "Running"
    )
    process_compose.wait_until(lambda procs:
      procs["redis2"]["status"] == "Running"
    )
    machine.succeed("${config.services.redis.redis1.package}/bin/redis-cli ping | grep -q 'PONG'")
    machine.succeed("${config.services.redis.redis2.package}/bin/redis-cli -p 6380 ping | grep -q 'PONG'")
  '';
}
