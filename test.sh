set -euxo pipefail

cd "$(dirname "$0")"

# On NixOS, run the VM tests to test runtime behaviour
if command -v nixos-rebuild &> /dev/null; then
  # example test
  nix flake check -L ./example --override-input services-flake .

  # service tests
  nix flake check -L ./test --override-input services-flake .
fi
