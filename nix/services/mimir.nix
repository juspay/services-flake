{
  pkgs,
  lib,
  name,
  config,
  ...
}:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    package = lib.mkPackageOption pkgs "mimir" { };

    httpAddress = lib.mkOption {
      type = types.str;
      description = "Which address to access mimir from.";
      default = "127.0.0.1";
    };

    httpPort = lib.mkOption {
      type = types.port;
      description = "Which port to run mimir on.";
      default = 8080; # Likely to be overridden by consumers due to likelihood of overlapping with common ports but this is the Mimir default
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Specify the configuration for Mimir in Nix.

        See https://grafana.com/docs/mimir/latest/configure/configuration-parameters/ for available options.
      '';
    };

    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''[ "-config.expand-env=true" ]'';
      description = "Additional flags to pass to mimir.";
    };
  };

  config = {
    outputs = {
      settings = {
        processes."${name}" =
          let
            mimirConfig = lib.recursiveUpdate {
              multitenancy_enabled = false;
              server = {
                http_listen_address = config.httpAddress;
                http_listen_port = config.httpPort;
              };
              memberlist = {
                bind_addr = [ config.httpAddress ];
                advertise_addr = config.httpAddress;
              };
              blocks_storage = {
                backend = "filesystem";
                filesystem.dir = "${config.dataDir}/blocks";
                bucket_store.sync_dir = "${config.dataDir}/tsdb-sync";
                tsdb.dir = "${config.dataDir}/tsdb";
              };
              compactor = {
                data_dir = "${config.dataDir}/compactor";
                sharding_ring = {
                  instance_addr = config.httpAddress;
                  kvstore.store = "memberlist";
                };
              };
              distributor.ring = {
                instance_addr = config.httpAddress;
                kvstore.store = "memberlist";
              };
              ingester.ring = {
                instance_addr = config.httpAddress;
                kvstore.store = "memberlist";
                replication_factor = 1;
              };
              store_gateway.sharding_ring = {
                instance_addr = config.httpAddress;
                replication_factor = 1;
              };
              frontend.address = config.httpAddress;
              ruler = {
                rule_path = "${config.dataDir}/ruler";
                ring.instance_addr = config.httpAddress;
              };
              ruler_storage = {
                backend = "filesystem";
                filesystem.dir = "${config.dataDir}/rules";
              };
            } config.extraConfig;
            mimirConfigYaml = yamlFormat.generate "mimir.yaml" mimirConfig;
            startScript = pkgs.writeShellApplication {
              name = "start-mimir";
              runtimeInputs = [ config.package ];
              text = ''
                exec mimir -target=all -config.file=${mimirConfigYaml} ${lib.escapeShellArgs config.extraFlags}
              '';
            };
          in
          {
            command = startScript;
            readiness_probe = {
              http_get = {
                host = config.httpAddress;
                scheme = "http";
                port = config.httpPort;
                path = "/ready";
              };
              initial_delay_seconds = 15;
              period_seconds = 10;
              timeout_seconds = 2;
              success_threshold = 1;
              failure_threshold = 5;
            };
            availability = {
              restart = "on_failure";
              max_restarts = 5;
            };
          };
      };
    };
  };
}
