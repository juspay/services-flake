default:
    @just --list

# Run example
ex:
    cd ./example && nix run . --override-input services-flake ..

# Auto-format the project tree
fmt:
    treefmt

# Run native tests
test:
    nix flake check test/ --override-input services-flake . -L
