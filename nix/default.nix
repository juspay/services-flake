{ pkgs, lib, ... }:
let
  # Create an attrsOf module wrapper (`services.${name}`) around the given submodule.
  #
  # where module filename is of form `${name}.nix`. The submodule takes this
  # 'name' parameter, and is expected to set the final process-compose config in
  # its `outputs.settings` option.
  multiService = mod:
    let
      # Derive name from filename
      name = lib.pipe mod [
        builtins.baseNameOf
        (lib.strings.splitString ".")
        builtins.head
      ];
    in
    { config, ... }: {
      options.services.${name} = lib.mkOption {
        description = ''
          ${name} service
        '';
        default = { };
        type = lib.types.attrsOf (lib.types.submoduleWith {
          specialArgs = { inherit pkgs; };
          modules = [ mod ];
        });
      };
      config.settings.imports =
        lib.pipe config.services.${name} [
          (lib.filterAttrs (_: cfg: cfg.enable))
          (lib.mapAttrsToList (_: cfg: cfg.outputs.settings))
        ];
    };
in
{
  imports = builtins.map multiService [
    ./apache-kafka.nix
    ./postgres.nix
    ./redis.nix
    ./redis-cluster.nix
    ./elasticsearch.nix
    ./zookeeper.nix
  ];
}
