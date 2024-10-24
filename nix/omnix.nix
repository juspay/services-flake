let
  root = ../.;
in
{
  # CI configuration; to run locally, `nix --accept-flake-config github:juspay/omnix ci`
  ci.default = let overrideInputs = { "services-flake" = root; }; in {
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
        northwind = (root + /example/share-services/northwind);
      };
      dir = "./example/share-services/pgweb";
    };
    without-flake-parts-example = {
      inherit overrideInputs;
      dir = "./example/without-flake-parts";
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
}
