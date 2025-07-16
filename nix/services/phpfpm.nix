{ config
, lib
, name
, pkgs
, ...
}:
let
  inherit (lib) types;

  toStr =
    value:
    if true == value then
      "yes"
    else if false == value then
      "no"
    else
      toString value;

  configType =
    with types;
    attrsOf (oneOf [
      str
      int
      bool
    ]);
in
{
  options = {
    package = lib.mkPackageOption pkgs "php" { };

    listen = lib.mkOption {
      type = types.either types.port types.str;
      default = "phpfpm.sock";
      description = ''
        The address on which to accept FastCGI requests.
      '';
    };

    phpOptions = lib.mkOption {
      type = types.lines;
      default = "";
      example = ''
        date.timezone = "CET"
      '';
      description = ''
        Options appended to the PHP configuration file {file}`php.ini` used for this PHP-FPM pool.
      '';
    };

    phpEnv = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Environment variables used for this PHP-FPM pool.
      '';
      example = lib.literalExpression ''
        {
          HOSTNAME = "$HOSTNAME";
          TMP = "/tmp";
          TMPDIR = "/tmp";
          TEMP = "/tmp";
        }
      '';
    };

    extraConfig = lib.mkOption {
      type = configType;
      default = { };
      description = ''
        PHP-FPM pool directives. Refer to the "List of pool directives" section of
        <https://www.php.net/manual/en/install.fpm.configuration.php>
        for details. Note that settings names must be enclosed in quotes (e.g.
        `"pm.max_children"` instead of `pm.max_children`).
      '';
      example = lib.literalExpression ''
        {
          "pm" = "dynamic";
          "pm.max_children" = 75;
          "pm.start_servers" = 10;
          "pm.min_spare_servers" = 5;
          "pm.max_spare_servers" = 20;
          "pm.max_requests" = 500;
        }
      '';
    };

    globalSettings = lib.mkOption {
      type = configType;
      default = { };
      description = ''
        PHP-FPM global directives. Refer to the "List of global php-fpm.conf directives" section of
        <https://www.php.net/manual/en/install.fpm.configuration.php>
        for details. Note that settings names must be enclosed in quotes (e.g.
        `"pm.max_children"` instead of `pm.max_children`).
        Do not specify the options `error_log` or
        `daemonize` here, since they are generated.
      '';
      example = lib.literalExpression ''
        {
          "log_level" = "debug";
        }
      '';
    };
  };
  config = {
    extraConfig.listen = lib.mkDefault config.listen;

    outputs.settings = {
      processes.${name} =
        let
          mergedGlobalSettings = {
            "daemonize" = false;
            "error_log" = "/proc/self/fd/2";
          } // config.globalSettings;
          cfgFile = pkgs.writeText "phpfpm-${name}.conf" ''
            [global]
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") mergedGlobalSettings)}

            [${name}]
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") config.extraConfig)}
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "env[${n}] = ${toStr v}") config.phpEnv)}
          '';
          iniFile =
            pkgs.runCommand "php.ini"
              {
                inherit (config) phpOptions;
                preferLocalBuild = true;
                passAsFile = [ "phpOptions" ];
              }
              ''
                cat ${config.package}/etc/php.ini $phpOptionsPath > $out
              '';
        in
        {
          command = pkgs.writeShellApplication {
            name = "start-phpfpm";
            runtimeInputs = [ config.package ];
            text = ''
              DATA_DIR="$(readlink -m ${config.dataDir})"
              if [[ ! -d "$DATA_DIR" ]]; then
                mkdir -p "$DATA_DIR"
              fi
              exec php-fpm -p "$DATA_DIR" -y ${cfgFile} -c ${iniFile}
            '';
          };

          readiness_probe =
            let
              # Transform `listen` by prefixing `config.dataDir` if a relative path is used
              transformedListen =
                if (builtins.isString config.listen && (! lib.hasPrefix "/" config.listen)) then
                  "${config.dataDir}/${config.listen}"
                else
                  config.listen;
            in
            {
              exec.command =
                if (builtins.isInt config.listen) then
                  "env -i ${pkgs.fcgi}/bin/cgi-fcgi -bind -connect 127.0.0.1:${toString config.listen}"
                else
                  "env -i ${pkgs.fcgi}/bin/cgi-fcgi -bind -connect ${transformedListen}";

              initial_delay_seconds = 2;
              period_seconds = 10;
              timeout_seconds = 4;
              success_threshold = 1;
              failure_threshold = 5;
            };
        };
    };
  };
}
