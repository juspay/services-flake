{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      pre-commit = {
        check.enable = true;
        settings = {
          rootSrc = lib.mkForce inputs.services-flake;
          hooks = {
            commitizen.enable = true;

            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
              pass_filenames = false; # treefmt walks the tree itself.
            };
          };
        };
      };
    };
}
