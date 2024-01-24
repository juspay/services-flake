# Based on: https://github.com/cachix/devenv/blob/main/src/modules/services/clickhouse.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkOption {
      type = types.package;
      description = "Which package of clickhouse to use";
      default = pkgs.clickhouse;
      defaultText = lib.literalExpression "pkgs.clickhouse";
    };

    port = lib.mkOption {
      type = types.int;
      description = "Which port to run clickhouse on. This port is for `clickhouse-client` program";
      default = 9000;
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The clickhouse data directory";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      description = "Additional configuration to be appended to `clickhouse-config.yaml`.";
      default = "";
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}" =
            let
              clickhouseConfig = pkgs.writeText "clickhouse-config.yaml" ''
                logger:
                  level: warning
                  console: 1
                tcp_port: ${toString config.port}
                default_profile: default
                default_database: default
                path: ${config.dataDir}/clickhouse
                tmp_path: ${config.dataDir}/clickhouse/tmp
                user_files_path: ${config.dataDir}/clickhouse/user_files
                format_schema_path: ${config.dataDir}/clickhouse/format_schemas
                user_directories:
                  users_xml:
                    path: ${config.package}/etc/clickhouse-server/users.xml
                ${config.extraConfig}
              '';
              startScript = pkgs.writeShellApplication {
                name = "start-clickhouse";
                runtimeInputs = [ config.package ];
                text = ''
                  clickhouse-server --config-file=${clickhouseConfig}
                '';
              };
            in
            {
              command = "${lib.getExe startScript}";

              readiness_probe = {
                exec.command = ''${config.package}/bin/clickhouse-client --query "SELECT 1" --port ${builtins.toString config.port}'';
                initial_delay_seconds = 2;
                period_seconds = 10;
                timeout_seconds = 4;
                success_threshold = 1;
                failure_threshold = 5;
              };
              namespace = name;

              # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
              availability.restart = "on_failure";
            };
        };
      };
    };
  };
}
