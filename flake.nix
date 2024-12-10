{
  description = "declarative, composable, and reproducible services for Nix development environment";
  outputs = _: {
    processComposeModules.default = ./nix/services;

    templates.default = {
      description = "Example flake using process-compose-flake";
      path = builtins.path { path = ./example/simple; filter = path: _: baseNameOf path == "flake.nix"; };
    };

    lib = import ./nix/lib.nix;

    om = import ./nix/omnix.nix;
  };
}
