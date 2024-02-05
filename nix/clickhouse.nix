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

    initialDatabases = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = ''
              The name of the database to create.
            '';
          };
          schemas = lib.mkOption {
            type = types.nullOr (types.listOf types.path);
            default = null;
            description = ''
              The initial list of schemas for the database; if null (the default),
              an empty database is created.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        List of database names and their initial schemas that should be used to create databases on the first startup
        of Postgres. The schema attribute is optional: If not specified, an empty database is created.
      '';
      example = lib.literalExpression ''
        [
          {
            name = "foodatabase";
            schemas = [ ./fooschemas ./bar.sql ];
          }
          { name = "bardatabase"; }
        ]
      '';
    };
    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes =
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
          in
          {
            # DB initialization
            "${name}-init" =
              let
                # https://github.com/ClickHouse/ClickHouse/issues/4491
                setupInitialSchema = schema: '' < ${schema} tr -s '\r\n' ' ' | clickhouse-client -mn --port ${builtins.toString config.port}; '';
                setupInitialDatabases =
                  lib.concatMapStrings
                    (database: ''
                      echo "Creating database: ${database.name}"
                      clickhouse-client --port ${builtins.toString config.port} --query "CREATE DATABASE iF NOT EXISTS ${database.name}"
                      echo "Database successfully created: ${database.name}"
                      ${lib.optionalString (database.schemas != null)
                        (lib.concatMapStrings (schema: setupInitialSchema schema) database.schemas)}
                    '')
                    config.initialDatabases;
                setupScript = pkgs.writeShellApplication {
                  name = "setup-clickhouse";
                  runtimeInputs = with pkgs; [ config.package coreutils gnugrep gawk ];
                  text = ''
                    if test -d ${config.dataDir}
                      then echo "Clickhouse database directory ${config.dataDir} appears to contain a database; Skipping initialization"
                      else
                        echo "Clickhouse is setting up the initial database."
                        set -m
                        clickhouse-server --config-file=${clickhouseConfig} &
                        sleep 5s
                        echo "Clickhouse server started."
                        ${setupInitialDatabases}
                        echo "Clickhouse db setting is done."
                        kill %1
                        echo "Clickhouse server stopped."
                    fi
                  '';
                };
              in
              {
                command = setupScript;
                namespace = name;
              };

            # DB process
            "${name}" =
              let
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
                depends_on."${name}-init".condition = "process_completed_successfully";
                # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
                availability.restart = "on_failure";
              };
          };
      };
    };
  };
}
