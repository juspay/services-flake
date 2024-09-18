# MongoDB

[MongoDB](https://www.mongodb.com/) is a popular document database that is available. It comes in a variety of flavors, but the version packaged by NixPkgs is generally the community edition.

Because of the licensing of MongoDB, the Nixpkgs derivation that provides the binaries of this database are generally not built and cached by the public nixpkgs cache. Because of this, the initial launch time can be very slow, the first time you use this service locally. On a laptop this time ran to about 3 hours for the initial compile. After the initial build, the start up should be very fast, as with other services, provided you do not update your flake.lock.

If you are using this for your own development, you should either put in place a [local binary cache](https://nixos.wiki/wiki/Binary_Cache) to match your flake, or be aware that the first time you spin up the service it could possibly take a long time to build.

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/mongodb_test.nix>
