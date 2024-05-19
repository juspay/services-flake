{ pkgs, config, ... }: {
  services.tempo."tp1" =
    {
      enable = true;
      httpPort = 3200;
    };

  settings.processes.test =
    let
      cfg = config.services.tempo."tp1";
    in
    {
      # Tests based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/grafana/basic.nix
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl pkgs.uutils-coreutils-noprefix ];
        text =
          ''
            ROOT_URL="http://${cfg.httpAddress}:${builtins.toString cfg.httpPort}";
            curl -sSfN $ROOT_URL/status/version | grep "tempo, version"
          '';
        name = "tempo-test";
      };
      depends_on."tp1".condition = "process_healthy";
    };
}
