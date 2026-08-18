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

      # Markdown, JSON, YAML, etc.
      programs.prettier.enable = true;

      # Nix
      programs.nixfmt.enable = true;
    };
  };
}
