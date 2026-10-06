# Docs site for services-flake, based on
# https://github.com/srid/emanote-template
#
#   nix run ./doc     — live preview at http://localhost:5566
#   nix build ./doc   — static site (result/)
#
# `result/` is deployed to GitHub Pages by `.github/workflows/pages.yaml`,
# which serves it at the https://services.nixos.asia custom domain.
{
  nixConfig = {
    extra-substituters = "https://cache.nixos.asia/oss";
    extra-trusted-public-keys = "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU=";
  };

  inputs = {
    emanote.url = "github:srid/emanote";
    emanote.inputs.emanote-template.follows = "";
    nixpkgs.follows = "emanote/nixpkgs";
    flake-parts.follows = "emanote/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.emanote.flakeModule
      ];
      perSystem =
        { ... }:
        {
          emanote.sites.default = {
            layers = [
              {
                path = ./.;
                pathString = ".";
              }
            ];
            port = 5566;
            # No link-checking: html-proofer rejects the
            # `http://127.0.0.1:...` URLs documented in alloy.md and
            # openobserve.md.
            check = false;
          };
        };
    };
}
