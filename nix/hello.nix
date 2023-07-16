{ pkgs, lib, options, config, ... }:

{
  options.services.hello = lib.mkOption {
    type = with lib.types; attrsOf (submodule ({ name, config, ... }:
      let serviceName = "hello-${name}"; in {
        options = {
          enable = lib.mkEnableOption "hello";
          name = lib.mkOption {
            type = lib.types.str;
            default = "hello";
            description = "Process name";
          };
          package = lib.mkPackageOption pkgs "hello" { };
          greeting = lib.mkOption {
            type = lib.types.str;
            default = "Hello";
            description = "The greeting to use";
          };
          output = lib.mkOption {
            type = (options.settings.type.getSubOptions [ ]).processes.type;
            internal = true;
            readOnly = true;
            default = {
              "${serviceName}".command = ''
                set -x
                ${lib.getExe config.package} -g "${config.greeting}"
              '';
            };
          };
        };
      }));
  };
  config = {
    settings.processes = lib.mkMerge (lib.mapAttrsToList (_: cfg: lib.mkIf cfg.enable cfg.output) config.services.hello);
  };
}
