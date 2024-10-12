# MongoDB

[MongoDB](https://www.mongodb.com/) is a popular document database that is available. It comes in a variety of flavors, but the version packaged by NixPkgs is generally the community edition.

Because of the licensing of MongoDB, the Nixpkgs derivation that provides the binaries of this database are generally not built and cached by the public nixpkgs cache. Because of this, the initial launch time can be very slow, the first time you use this service locally. On a laptop this time ran to about 3 hours for the initial compile. After the initial build, the start up should be very fast, as with other services, provided you do not update your flake.lock.

If you are using this for your own development, you should either put in place a [local binary cache](https://nixos.wiki/wiki/Binary_Cache) to match your flake, or be aware that the first time you spin up the service it could possibly take a long time to build.

## Pre-built binaries

[mongodb-ce](https://github.com/NixOS/nixpkgs/blob/e58a261efb95afd52fb4a1cf35185a017327a96d/pkgs/by-name/mo/mongodb-ce/package.nix) package from [nixpkgs](https://github.com/NixOS/nixpkgs) fetches pre-built binaries[^why-pre-built]. You can also build the binary from scratch using [mongodb](https://github.com/NixOS/nixpkgs/blob/924e8aa12419c6ac57690ed47c1d9af580c818a2/pkgs/servers/nosql/mongodb/mongodb.nix) package:

```nix
# Inside `process-compose.<name>`
{
  services.mongodb."m1" = {
    enable = true;
    package = pkgs.mongodb;
  };
}
```

[why-pre-built]: For more context on why pre-built binary is used, see: https://github.com/juspay/services-flake/pull/360

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/mongodb_test.nix>
