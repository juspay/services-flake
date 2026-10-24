{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types;

  # `outputs` is a reserved attribute set and is not the name of a service.
  services = lib.filterAttrs (n: _: n != "outputs") config.services;

  # A single-instance service defines its options (including `enable`) directly under
  # `services.<service>`, whereas a multi-instance service nests them under
  # `services.<service>.<instance>`.
  # See https://community.flake.parts/services-flake/custom-service#single-instance
  isSingleInstance = cfg: lib.isBool (cfg.enable or null);

  singleInstanceServices = lib.filterAttrs (_: isSingleInstance) services;
  multiInstanceServices = lib.filterAttrs (_: cfg: !isSingleInstance cfg) services;

  singleInstancePackages = lib.pipe singleInstanceServices [
    (lib.filterAttrs (_: cfg: cfg.enable))
    (lib.mapAttrsToList (
      service: cfg: cfg.package or (builtins.throw "${service} doesn't define a `package` option")
    ))
  ];
in
{
  options.services.outputs = {
    enabledServices = lib.mkOption {
      type = types.attrsOf (types.listOf types.str);
      readOnly = true;
      description = ''
        Names of all the enabled instances of multi-instance services, grouped by the service name.
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
    services.outputs.enabledServices = lib.pipe multiInstanceServices [
      (lib.mapAttrs (_service: instances: lib.attrNames (lib.filterAttrs (_: v: v.enable) instances)))
    ];

    services.outputs.devShell = pkgs.mkShell {
      packages = lib.pipe config.services.outputs.enabledServices [
        (lib.mapAttrsToList (
          service: instances:
          map (
            instance:
            lib.attrByPath ([
              service
              instance
              "package"
            ]) (builtins.throw "${service}.${instance} doesn't define a `package` option") config.services
          ) instances
        ))

        lib.flatten

        (packages: packages ++ singleInstancePackages)
      ];
    };
  };
}
