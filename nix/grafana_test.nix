{ pkgs, config, ... }:
let
  dashboardUid = "adnyzrfa5cqv4c";
  dashboardTitle = "Test dashboard";
  dashboards = pkgs.writeTextDir "dashboards/test_dashboard.json" ''
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": {
              "type": "grafana",
              "uid": "-- Grafana --"
            },
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "type": "dashboard"
          }
        ]
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": 3,
      "links": [],
      "panels": [],
      "schemaVersion": 39,
      "tags": [],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "browser",
      "title": "${dashboardTitle}",
      "uid": "${dashboardUid}",
      "version": 1,
      "weekStart": ""
    }
  '';
in
{
  services.grafana."gf1" =
    {
      enable = true;
      http_port = 3000;
      extraConf = {
        security.admin_user = "patato";
        security.admin_password = "potato";
      };
      providers = [
        {
          name = "Test dashboard provider";
          type = "file";
          options = {
            path = "${dashboards}/dashboards";
          };
        }
      ];
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
            # The admin user can authenticate against the running service.
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/org/users -i
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/org/users | grep admin\@localhost
            # The dashboard provisioner was used to create a dashboard.
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/dashboards/uid/${dashboardUid} -i
            curl -sSfN -u $ADMIN:$PASSWORD $ROOT_URL/api/dashboards/uid/${dashboardUid} | grep '"title":"${dashboardTitle}"'
          '';
        name = "grafana-test";
      };
      depends_on."gf1".condition = "process_healthy";
    };
}
