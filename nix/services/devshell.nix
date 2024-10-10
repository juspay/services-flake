{ config, pkgs, lib, ... }:
let
  inherit (lib) types;
in
{
  options.services.outputs = {
    enabledServices = lib.mkOption {
      type = types.listOf (types.listOf types.str);
      readOnly = true;
      description = ''
        List of names of enabled services.

        Each item will be of the form [ "<service>" "<instance-name>" ]
      '';
      example = lib.literalExpression ''
        [ [ "mysql" "m1" ] [ "mysql" "m2" ] [ "redis" "r1" ] ]
      '';
    };
    devShell = lib.mkOption {
      type = types.package;
      readOnly = true;
      description = ''
        The devShell that aggregates packages from all the enabled services.
      '';
    };
  };

  config = {
    services.outputs.enabledServices = lib.pipe config.services [
      # `outputs` is a reserved attribute set and is not the name of a service.
      (lib.filterAttrs (n: _: n != "outputs"))

      (lib.foldlAttrs
        (acc: service: instances:
          (lib.mapAttrsToList
            (name: cfg:
              if cfg.enable then [ service name ] else [ ]
            )
            instances)
          ++ acc
        ) [ ])

      (lib.filter (enabledService: enabledService != [ ]))
    ];
    services.outputs.devShell = pkgs.mkShell {
      packages = map
        (name:
          lib.attrByPath (name ++ [ "package" ]) (builtins.throw "${builtins.toString name} doesn't define a `package` option") config.services
        )
        config.services.outputs.enabledServices;
    };
  };
}
