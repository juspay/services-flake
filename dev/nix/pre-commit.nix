{ inputs, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    pre-commit = {
      check.enable = true;
      settings = {
        rootSrc = lib.mkForce inputs.services-flake;
        hooks = {
          nixfmt.enable = true;
          commitizen.enable = true;
        };
      };
    };
  };
}
