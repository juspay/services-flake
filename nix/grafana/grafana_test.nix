{ pkgs, config, ... }: {
  services.grafana."gf1" =
    {
      enable = true;
      http_port = 3000;
      extraConf = {
        security.admin_user = "patato";
        security.admin_password = "potato";
      };
    };

  settings.processes.test =
    let
      cfg = config.services.grafana."gf1";
    in
    {
      # Tests based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/grafana/basic.nix
      command = pkgs.writeShellApplication {
        runtimeInputs = [ cfg.package pkgs.gnugrep pkgs.curl pkgs.uutils-coreutils-noprefix ];
        text =
          ''
            ADMIN=${cfg.extraConf.security.admin_user}
            PASSWORD=${cfg.extraConf.security.admin_password}
            ROOT_URL="${cfg.protocol}://${cfg.domain}:${builtins.toString cfg.http_port}";
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/org/users -i
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/org/users | grep admin\@localhost
          '';
        name = "grafana-test";
      };
      depends_on."gf1".condition = "process_healthy";
    };
}
