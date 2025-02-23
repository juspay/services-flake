{
  # Create an attrsOf module wrapper (`services.${name}`) around the given submodule.
  #
  # where module filename is of form `${name}.nix`. The submodule takes this
  # 'name' parameter, and is expected to set the final process-compose config in
  # its `outputs.settings` option.
  multiService = name: mod:
    { config, pkgs, lib, ... }:
    let
      # Derive name from filename
      service = lib.pipe mod [
        builtins.baseNameOf
        (lib.strings.splitString ".")
        builtins.head
      ];
      serviceModule = { config, name, ... }: {
        options = {
          enable = lib.mkEnableOption "Enable the ${service}.<name> service";
          # FIXME: `multiService` lib should be devoid of process-compose specific options
          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "./data/${name}";
            description = "The directory where all data for `${service}.<name>` is stored";
          };
          # FIXME: `multiService` lib should be devoid of process-compose specific options
          namespace = lib.mkOption {
            description = ''
              Namespace for the ${service} service
            '';
            default = "${service}.${name}";
            type = lib.types.str;
          };
          outputs = {
            # FIXME: `multiService` lib should be devoid of process-compose specific options
            defaultProcessSettings = lib.mkOption {
              type = lib.types.deferredModule;
              internal = true;
              readOnly = true;
              description = ''
                Default settings for all processes under the ${service} service
              '';
              default = {
                namespace = lib.mkDefault config.namespace;
              };
            };
            # FIXME: rename to `process-compose`
            settings = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.raw;
              internal = true;
              description = ''
                process-compose settings for the processes under the ${service} service
              '';
              apply = v: v // {
                processes = lib.flip lib.mapAttrs v.processes (_: cfg:
                  { imports = [ config.outputs.defaultProcessSettings cfg ]; }
                );
              };
            };
            systemd = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.deferredModule;
              internal = true;
              default = { };
            };
            launchd = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.deferredModule;
              internal = true;
              default = { };
            };
          };
        };
      };
    in
    {
      options = {
        services.${service} = lib.mkOption {
          description = ''
            ${service} service
          '';
          default = { };
          type = lib.types.attrsOf (lib.types.submoduleWith {
            specialArgs = { inherit pkgs; };
            modules = [
              serviceModule
              mod
            ];
          });
        };
      };
      config = lib.optionalAttrs (name == "homeModules")
        {
          systemd.user.services = lib.pipe config.services.${service} [
            (lib.filterAttrs (_: cfg: cfg.enable))
            (lib.concatMapAttrs (_: cfg: cfg.outputs.systemd))
          ];
          launchd.agents = lib.pipe config.services.${service} [
            (lib.concatMapAttrs (_: cfg: lib.mapAttrs (_: cf: { ... }: { imports = [ cf ]; }) cfg.outputs.launchd))
          ];
        }
      // lib.optionalAttrs (name == "processComposeModules") {
        settings = {
          imports =
            lib.pipe config.services.${service} [
              (lib.filterAttrs (_: cfg: cfg.enable))
              (lib.mapAttrsToList (_: cfg: cfg.outputs.settings))
            ];
        };
      };
    };
}
