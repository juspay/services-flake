{
  description = "declarative, composable, and reproducible services for Nix development environment";
  outputs = _: {
    processComposeModules.default = ./nix;

    templates.default = {
      description = "Example flake using process-compose-flake";
      path = builtins.path { path = ./example/simple; filter = path: _: baseNameOf path == "flake.nix"; };
    };

    lib = import ./nix/lib.nix;

    # Config for https://github.com/srid/nixci
    # To run this, `nix run github:srid/nixci`
    nixci.default = let overrideInputs = { "services-flake" = ./.; }; in {
      simple-example = {
        inherit overrideInputs;
        dir = "./example/simple";
      };
      llm-example = {
        inherit overrideInputs;
        dir = "./example/llm";
      };
      share-services-example = {
        overrideInputs = {
          inherit (overrideInputs) services-flake;
          northwind = ./example/share-services/northwind;
        };
        dir = "./example/share-services/pgweb";
      };
      test = {
        inherit overrideInputs;
        dir = "./test";
      };
      dev = {
        inherit overrideInputs;
        dir = "./dev";
      };
      doc = {
        dir = "./doc";
      };
    };
  };
}
