# RustFS

[RustFS](https://github.com/rustfs/rustfs) is a high-performance, distributed object storage system written in Rust. It is compatible with the Amazon S3 API and can be used as a drop-in alternative to MinIO.

RustFS is not in nixpkgs. You must provide the package yourself via [`package`](#options), e.g. from the [`rustfs`](https://github.com/rustfs/rustfs) flake input.

## Getting Started

```nix
{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    process-compose."default" = {
      services.rustfs."s3" = {
        enable = true;
        package = inputs.rustfs.packages.${system}.default;

        server.port = 9000;          # S3 API
        console.enable = true;
        console.port = 9001;         # Web console

        accessKey = "rustfsadmin";   # 5 to 20 characters
        secretKey = "rustfsadmin";   # 8 to 40 characters
      };
    };
  };
}
```

The S3 API is then available at `http://127.0.0.1:9000` and the web console at
`http://127.0.0.1:9001`.

## Usage Example

<https://github.com/juspay/services-flake/blob/main/nix/services/rustfs_test.nix>
