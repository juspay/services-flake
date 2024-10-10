{ config, pkgs, lib, ... }:
let
  inherit (lib) types;
in
{
  options.services.outputs = {
    enabledServices = lib.mkOption {
      type = types.attrsOf (types.listOf types.str);
      readOnly = true;
      description = ''
        Names of all the enabled service instances, grouped by the service name.
      '';
      example = lib.literalExpression ''
        {
          mysql = [ "m1" "m2" ];
          redis = [ "r1" ];
        }
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

      (lib.mapAttrs (_service: instances:
        lib.attrNames (lib.filterAttrs (_: v: v.enable) instances)))
    ];

    services.outputs.devShell = pkgs.mkShell {
      packages = lib.pipe config.services.outputs.enabledServices [
        (lib.mapAttrsToList (service: instances:
          map
            (instance:
              lib.attrByPath ([ service instance "package" ]) (builtins.throw "${service}.${instance} doesn't define a `package` option") config.services)
            instances))

        lib.flatten
      ];
    };
  };
}
