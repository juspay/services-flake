{ config, ... }: {
  services.redis.enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      # TODO: Check for 'ready'
      procs["redis"]["status"] == "Running"
    )
    machine.succeed("${config.services.redis.package}/bin/redis-cli ping | grep -q 'PONG'")
  '';
}
