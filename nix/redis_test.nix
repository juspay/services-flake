{ config, ... }: {
  services.redis."redis1".enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'is_ready' instead of 'status'
      procs["redis1"]["status"] == "Running"
    )
    machine.succeed("${config.services.redis.redis1.package}/bin/redis-cli ping | grep -q 'PONG'")
  '';
}
