{
  outputs = _: {
    processComposeModules.default = ./nix;

    templates.default = {
      description = "Example flake using process-compose-flake";
      path = builtins.path { path = ./example; filter = path: _: baseNameOf path == "flake.nix"; };
    };

    lib = import ./nix/lib.nix;

    # Config for https://github.com/srid/nixci
    # To run this, `nix run github:srid/nixci`
    nixci.default = let overrideInputs = { "services-flake" = ./.; }; in {
      example = {
        inherit overrideInputs;
        dir = "./example";
      };
      test = {
        inherit overrideInputs;
        dir = "./test";
      };
      dev = {
        dir = "./dev";
      };
    };
  };
}
