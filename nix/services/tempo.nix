{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options = {
    description = ''
      Configure tempo.
    '';
    package = lib.mkPackageOption pkgs "tempo" { };

    httpAddress = lib.mkOption {
      type = types.str;
      description = "Which address to access tempo from.";
      default = "localhost";
    };

    httpPort = lib.mkOption {
      type = types.int;
      description = "Which port to run tempo on.";
      default = 3200;
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = lib.mdDoc ''
        Specify the configuration for Tempo in Nix.

        See https://grafana.com/docs/tempo/latest/configuration/ for available options.
      '';
    };

    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression
        ''
          [ "-config.expand-env=true" ]
        '';
      description = lib.mdDoc ''
        Additional flags to pass to tempo.
      '';
    };
  };

  config = {
    outputs = {
      settings = {
        processes."${name}" =
          let
            tempoConfig = lib.recursiveUpdate
              {
                server = {
                  http_listen_address = config.httpAddress;
                  http_listen_port = config.httpPort;
                };
                storage = {
                  trace = {
                    backend = "local";
                    wal = {
                      path = "${config.dataDir}/wal";
                    };
                    local = {
                      path = "${config.dataDir}/blocks";
                    };
                  };
                };
                distributor = {
                  receivers = {
                    jaeger = {
                      protocols = {
                        thrift_http = null;
                        grpc = null;
                        thrift_binary = null;
                        thrift_compact = null;
                      };
                    };
                    zipkin = null;
                    otlp = {
                      protocols = {
                        http = null;
                        grpc = null;
                      };
                    };
                    opencensus = null;
                  };
                };
              }
              config.extraConfig;
            tempoConfigYaml = yamlFormat.generate "tempo.yaml" tempoConfig;
            startScript = pkgs.writeShellApplication {
              name = "start-tempo";
              runtimeInputs =
                [ config.package ] ++
                (lib.lists.optionals pkgs.stdenv.isDarwin [
                  pkgs.coreutils
                ]);
              text = ''
                tempo --config.file=${tempoConfigYaml} ${lib.escapeShellArgs config.extraFlags}
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
