{ pkgs, config, ... }: {
  services.nginx."nginx1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.nginx."nginx1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl ];
        text = ''
          curl http://127.0.0.1:${builtins.toString cfg.port} | grep -q "nginx"
        '';
        name = "nginx-test";
      };
      depends_on."nginx1".condition = "process_healthy";
    };
}
