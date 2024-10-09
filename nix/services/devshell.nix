{ config, pkgs, lib, ... }:
{
  options.services.outputs.devShell = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      The devShell that aggregates packages from all the enabled services.
    '';
  };

  config = {
    services.outputs.devShell = pkgs.mkShell {
      packages =
        lib.pipe config.services [
          # `outputs` is a reserved attribute set and is not the name of a service.
          (lib.filterAttrs (n: _: n != "outputs"))
          # Flatten services attrset
          #
          # Example:
          # Input = { mysql."m1" = <cfg1>; mysql."m2" = <cfg2>; redis."r1" = <cfg3>; }
          # Output = [ <cfg1> <cfg2> <cfg3> ]
          (lib.foldlAttrs (acc: _: v: (lib.attrValues v) ++ acc) [ ])
          (lib.filter (service: service.enable))
          (map (service: service.package))
        ];
    };
  };
}
