default:
    @just --list

# Run example
ex:
    cd ./example && nix run . --override-input services-flake ..

# Auto-format the project tree
fmt:
    treefmt

# Run native tests for all the services
test-all:
    nix flake check test/ --override-input services-flake . -L

# `nix flake check` doesn't support individual checks: https://github.com/NixOS/nix/issues/8881
# Run native test for a specific service
test service:
    nix build ./test#checks.$(nix eval --impure --expr "builtins.currentSystem").{{service}} --override-input services-flake . -L
