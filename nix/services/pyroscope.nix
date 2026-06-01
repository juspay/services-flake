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
    package = lib.mkPackageOption pkgs "pyroscope" { };

    httpAddress = lib.mkOption {
      type = types.str;
      description = "Which address to access pyroscope from.";
      default = "127.0.0.1";
    };

    httpPort = lib.mkOption {
      type = types.port;
      description = "Which port to run pyroscope on.";
      default = 4040;
    };

    extraConfig = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Specify the configuration for Pyroscope in Nix.

        See https://grafana.com/docs/pyroscope/latest/configure-server/reference-configuration-parameters/ for available options.
      '';
    };
    extraFlags = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional flags to pass to pyroscope.";
    };
  };

  config = {
    outputs = {
      settings = {
        processes."${name}" =
          let
            pyroscopeConfig = lib.recursiveUpdate
              {
                server = {
                  http_listen_address = config.httpAddress;
                  http_listen_port = config.httpPort;
                };
                pyroscopedb = {
                  data_path = "${config.dataDir}/data";
                };
                storage = {
                  backend = "filesystem";
                  filesystem = {
                    dir = "${config.dataDir}/blocks";
                  };
                };
                ingester.lifecycler.address = config.httpAddress;
                distributor.ring.instance_addr = config.httpAddress;
                compactor.sharding_ring.instance_addr = config.httpAddress;
                overrides_exporter.ring.instance_addr = config.httpAddress;
                query_scheduler.ring.instance_addr = config.httpAddress;
                frontend.instance_addr = config.httpAddress;
                store_gateway.sharding_ring.instance_addr = config.httpAddress;
                memberlist.bind_addr = [ config.httpAddress ];
              }
              config.extraConfig;
            pyroscopeConfigYaml = yamlFormat.generate "pyroscope.yaml" pyroscopeConfig;
            startScript = pkgs.writeShellApplication {
              name = "start-pyroscope";
              runtimeInputs = [ config.package ];
              text = ''
                ${lib.getExe config.package} --config.file=${pyroscopeConfigYaml} ${lib.escapeShellArgs config.extraFlags}
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
