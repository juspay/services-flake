# List all the just commands
default:
    @just --list

# Generate CHANGELOG under `Unreleased`, starting from the previous release
changelog:
    cz ch --start-rev $(git describe --tags --abbrev=0 HEAD^) --incremental

# Run example/simple
[group('example')]
ex-simple:
    cd ./example/simple && nix run . --override-input services-flake ../..

# Run example/llm
[group('example')]
ex-llm:
    cd ./example/llm && nix run . --override-input services-flake ../..

# Run example/share-services
[group('example')]
ex-share-services:
    cd ./example/share-services/pgweb && \
        nix run . \
            --override-input services-flake ../../.. \
            --override-input northwind ../northwind \

# Auto-format the project tree
fmt:
    pre-commit run -a

# Run native tests for all the services
[group('test')]
test-all:
    nix flake check test/ --override-input services-flake . -L

# `nix flake check` doesn't support individual checks: https://github.com/NixOS/nix/issues/8881
# Run native test for a specific service
[group('test')]
test service:
    nix build ./test#checks.$(nix eval --impure --expr "builtins.currentSystem").{{service}} --override-input services-flake . -L

# Run doc server with hot-reload
[group('doc')]
doc:
    cd ./doc && nix run

# Build docs static website (this runs linkcheck automatically)
[group('doc')]
doc-static:
    nix build ./doc

# Run service whose configuration is defined in `<service>_test.nix`
run service:
    cd test && nix run .#{{service}} --override-input services-flake ../
