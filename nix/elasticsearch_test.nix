{ pkgs, config, ... }: {
  services.elasticsearch."es1".enable = true;
  testScript = ''
    process_compose.wait_until(lambda procs:
      procs["es1"]["status"] == "Running"
    )
    # Wait for Elasticsearch to start because checking for ready doesn't work in the `process_compose.wait_until` function
    machine.succeed("${pkgs.coreutils}/bin/sleep 20")
    machine.succeed("${pkgs.curl}/bin/curl 127.0.0.1:9200/_cat/health")
  '';
}
