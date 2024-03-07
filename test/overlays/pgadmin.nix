final: prev: {
  # Because tests are failing on darwin: https://github.com/NixOS/nixpkgs/issues/281214
  pgadmin4 = prev.pgadmin4.overrideAttrs (_: { doInstallCheck = false; });
}
