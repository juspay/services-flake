{ config, ... }: {
  services.redis."redis1".enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'is_ready' instead of 'status'
      procs["redis"]["status"] == "Running"
    )
    machine.succeed("${config.services.redis.package}/bin/redis-cli ping | grep -q 'PONG'")
  '';
}
