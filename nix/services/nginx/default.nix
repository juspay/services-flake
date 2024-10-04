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
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nginx;
      defaultText = "pkgs.nginx";
      description = "The nginx package to use.";
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

  };
  config = {
    outputs = {
      settings.processes =
        let
          startScript = pkgs.writeShellApplication {
            name = "start-nginx";
            runtimeInputs = [ pkgs.coreutils config.package ];
            text = ''
              set -euo pipefail
              if [[ ! -d "${config.dataDir}" ]]; then
                mkdir -p "${config.dataDir}"
              fi
              ln -sfn ${config.configFile} "${config.dataDir}/nginx.conf"
              nginx -p "$(pwd)" -c "${config.dataDir}/nginx.conf" -e /dev/stderr
            '';
          };
        in
        {
          "${name}" = {
            command = startScript;
            readiness_probe = {
              # FIXME need a better health check
              exec.command = "[ -e ${config.dataDir}/nginx/nginx.pid ]";
            };
          };
        };
    };
  };
}
