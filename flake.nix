{
  outputs = _: {
    processComposeModules.default = ./nix;

    templates.default = {
      description = "Example flake using process-compose-flake";
      path = builtins.path { path = ./example; filter = path: _: baseNameOf path == "flake.nix"; };
    };

    # Config for https://github.com/srid/nixci
    nixci = let overrideInputs = { "services-flake" = "."; }; in {
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
