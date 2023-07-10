{
  outputs = _: {
    processComposeModules.default = ./nix;

    templates.default = {
      description = "Example flake using process-compose-flake";
      path = builtins.path { path = ./example; filter = path: _: baseNameOf path == "flake.nix"; };
    };

    # Config for https://github.com/srid/nixci
    nixci = {
      flakeDir = "./dev";
      overrideInputs = rec {
        "services-flake" = ".";
        "example" = "./example";
        "example/services-flake" = services-flake;
      };
    };
  };
}
