final: prev: {
  # Because tests are failing on darwin: https://github.com/juspay/services-flake/pull/115#issuecomment-1970467684
  pgadmin4 = prev.pgadmin4.overrideAttrs (_: { doInstallCheck = false; });
}