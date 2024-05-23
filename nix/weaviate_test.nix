{ pkgs, config, ... }: {
  services.weaviate."weaviate1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.weaviate."weaviate1";
      testScript = pkgs.writeText "test.py" ''
        import weaviate

        client = weaviate.connect_to_local(
            port=${toString cfg.port},
            host="${cfg.host}"
        )
        client.close()
      '';
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          (pkgs.python3.withPackages (python-pkgs: [
            python-pkgs.weaviate-client
          ]))
        ];
        text = ''
          exec python3 ${testScript}
        '';
        name = "weaviate-test";
      };
      depends_on."weaviate1".condition = "process_healthy";
    };
}
