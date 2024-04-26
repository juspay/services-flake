# Based on: https://github.com/cachix/devenv/blob/main/src/modules/services/nginx.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
  configFile = pkgs.writeText "nginx.conf" ''
    pid ${config.dataDir}/nginx/nginx.pid;
    error_log stderr debug;
    daemon off;

    events {
      ${config.eventsConfig}
    }

    http {
      access_log off;
      client_body_temp_path ${config.dataDir}/nginx/;
      proxy_temp_path ${config.dataDir}/nginx/;
      fastcgi_temp_path ${config.dataDir}/nginx/;
      scgi_temp_path ${config.dataDir}/nginx/;
      uwsgi_temp_path ${config.dataDir}/nginx/;

      include ${config.defaultMimeTypes};

      server {
        listen ${builtins.toString config.port};
      }
      ${config.httpConfig}
    }

  '';
in

{
  options = {
    enable = lib.mkEnableOption "nginx";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nginx;
      defaultText = "pkgs.nginx";
      description = "The nginx package to use.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The nginx data directory";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8080;
      description = ''
        The TCP port to accept connections.
      '';
    };

    defaultMimeTypes = lib.mkOption {
      type = lib.types.path;
      default = "${pkgs.mailcap}/etc/nginx/mime.types";
      defaultText = lib.literalExpression "$''{pkgs.mailcap}/etc/nginx/mime.types";
      example = lib.literalExpression "$''{pkgs.nginx}/conf/mime.types";
      description = lib.mdDoc ''
        Default MIME types for NGINX, as MIME types definitions from NGINX are very incomplete,
        we use by default the ones bundled in the mailcap package, used by most of the other
        Linux distributions.
      '';
    };

    httpConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "The nginx configuration.";
    };

    eventsConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "The nginx events configuration.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = configFile;
      internal = true;
      description = "The nginx configuration file.";
    };

    configFilePath = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Provides optional setting to copy the config file to the user provided path.
        Useful for scenarios where you want to relatively import files in the config.
      '';
    };

    outputs.settings = lib.mkOption {
      type = lib.types.deferredModule;
      internal = true;
      readOnly = true;
      default =
        let
          startScript = pkgs.writeShellApplication {
            name = "start-nginx";
            runtimeInputs = [ pkgs.coreutils config.package ];
            text = ''
              set -euo pipefail
              if [[ ! -d "${config.dataDir}" ]]; then
                mkdir -p "${config.dataDir}"
              fi
              ${if isNull config.configFilePath then "" else "ln -sfn ${config.configFile} ${config.configFilePath}"}
              nginx -p "$(pwd)" -c "${if isNull config.configFilePath then config.configFile else config.configFilePath}" -e /dev/stderr
            '';
          };
        in
        {
          processes."${name}" = {
            command = startScript;
            readiness_probe = {
              # FIXME need a better health check
              exec.command = "[ -e ${config.dataDir}/nginx/nginx.pid ]";
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
}
