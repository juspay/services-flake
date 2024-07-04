{
  # Create an attrsOf module wrapper (`services.${name}`) around the given submodule.
  #
  # where module filename is of form `${name}.nix`. The submodule takes this
  # 'name' parameter, and is expected to set the final process-compose config in
  # its `outputs.settings` option.
  multiService = mod:
    { config, pkgs, lib, ... }:
    let
      # Derive name from filename
      service = lib.pipe mod [
        builtins.baseNameOf
        (lib.strings.splitString ".")
        builtins.head
      ];
    in
    {
      options.services.${service} = lib.mkOption {
        description = ''
          ${service} service
        '';
        default = { };
        type = lib.types.attrsOf (lib.types.submoduleWith {
          specialArgs = { inherit pkgs; };
          modules = [
            ({ name, ... }: {
              options.namespace = lib.mkOption {
                description = ''
                  Namespace for the ${service} service
                '';
                default = "${service}.${name}";
                type = lib.types.str;
              };
            })
            mod
          ];
        });
      };
      config.settings.imports =
        lib.pipe config.services.${service} [
          (lib.filterAttrs (_: cfg: cfg.enable))
          (lib.mapAttrsToList (_: cfg: cfg.outputs.settings))
        ];
    };
}
