{ ... }:
{
  perSystem = { pkgs, lib, ... }: {
    pre-commit = {
      check.enable = true;
      settings = {
        hooks = {
          nixpkgs-fmt.enable = true;
          commitizen.enable = true;
        };
      };
    };
  };
}
