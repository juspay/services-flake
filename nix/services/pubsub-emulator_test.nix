{ pkgs, config, ... }: {
  services.pubsub-emulator."pubsub-emulator1" = {
    enable = true;
    port = 8081;
    project = "test";
  };

  settings.processes.test =
    {
      command =
        let testConfig = config.services.pubsub-emulator.pubsub-emulator1;
        in
        pkgs.writeShellApplication {
          runtimeInputs = [ pkgs.curl ];
          text =
            ''
              [ "$(curl -sS http://${testConfig.host}:${builtins.toString testConfig.port})" = "Ok" ]
            '';
          name = "pubsub-emulator-test";
        };
      depends_on."pubsub-emulator1".condition = "process_healthy";
    };
}
