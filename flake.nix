{
  description = "declarative, composable, and reproducible services for Nix development environment";
  outputs = _:
    let modules = import ./nix/services; in {
      processComposeModules.default = modules.processComposeModules;
      homeModules.default = modules.homeModules;

      templates.default = {
        description = "Example flake using process-compose-flake";
        path = builtins.path { path = ./example/simple; filter = path: _: baseNameOf path == "flake.nix"; };
      };

      lib = import ./nix/lib.nix;

      om = import ./nix/omnix.nix;
    };
}
