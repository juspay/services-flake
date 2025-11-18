{ pkgs
, lib
, name
, config
, ...
}:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    package = lib.mkPackageOption pkgs "grafana-loki" { };

    httpAddress = lib.mkOption {
      type = types.str;
      description = "Which address to access loki from.";
      default = "localhost";
    };

    httpPort = lib.mkOption {
      type = types.port;
      description = "Which HTTP port to loki should listen on.";
      default = 3100;
    };

    grpcPort = lib.mkOption {
      type = types.port;
      description = "Which gRPC port to run loki should listen on.";
      default = 9096;
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Specify the configuration for Loki in Nix.

        See https://grafana.com/docs/loki/latest/configuration/ for available options.
      '';
    };

    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''
        [ "-config.expand-env=true" ]
      '';
      description = ''
        Additional flags to pass to loki.
      '';
    };
  };

  config = {
    outputs = {
      settings = {
        processes."${name}" =
          let
            lokiConfig = lib.recursiveUpdate
              {
                server = {
                  http_listen_port = config.httpPort;
                  grpc_listen_port = config.grpcPort;
                };
                common = {
                  instance_addr = config.httpAddress;
                  path_prefix = "${config.dataDir}/";
                  storage = {
                    filesystem = {
                      chunks_directory = "${config.dataDir}/chunks";
                      rules_directory = "${config.dataDir}/rules";
                    };
                  };
                  replication_factor = 1;
                  ring = {
                    kvstore = {
                      store = "inmemory";
                    };
                  };
                };
                schema_config = {
                  configs = [
                    {
                      from = "2020-10-24";
                      store = "tsdb";
                      object_store = "filesystem";
                      schema = "v13";
                      index = {
                        prefix = "index_";
                        period = "24h";
                      };
                    }
                  ];
                };
              }
              config.extraConfig;
            lokiConfigYaml = yamlFormat.generate "loki.yaml" lokiConfig;
          in
          {
            command = "${config.package}/bin/loki --config.file=${lokiConfigYaml} ${lib.escapeShellArgs config.extraFlags}";
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
