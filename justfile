default:
    @just --list

# Run example
ex:
    cd ./example && nix run . --override-input services-flake ..

# Auto-format the project tree
fmt:
    treefmt
