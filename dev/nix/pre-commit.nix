{ ... }:
{
  perSystem = { pkgs, lib, ... }: {
    pre-commit = {
      check.enable = true;
      settings = {
        hooks = {
          treefmt.enable = true;
          commitizen.enable = true;
        };
      };
    };
  };
}
