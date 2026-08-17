{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    treefmt = {
      # already checked in ./pre-commit.nix
      flakeCheck = false;

      # Used to find the project root
      # For worktrees we need either `.git` or a file.
      projectRootFile = "CHANGELOG.md";

      # Nix
      programs.nixfmt.enable = true;
    };
  };
}
