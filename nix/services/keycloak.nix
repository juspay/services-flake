# Based on Devenv's keycloak module:
# Ref: https://github.com/cachix/devenv/commit/32f6747aabbd5aeb7413bae53d7e01e224ec77bc
{
  ...
}:
{
  imports = [
    ./keycloak/service.nix
    ./keycloak/options.nix
  ];
}
