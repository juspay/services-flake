set -euxo pipefail

cd "$(dirname "$0")"

# TODO: use github:srid/nixci
nix flake check -L ./dev \
    --override-input services-flake . \
    --override-input example ./example \
    --override-input example/services-flake .
