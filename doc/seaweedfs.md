# SeaweedFS

[SeaweedFS](https://github.com/seaweedfs/seaweedfs) is a simple and highly scalable distributed file system that also provides an S3-compatible API.

The service runs `weed server`, which combines a master and volume server in a single process. The filer and S3 gateway can be enabled with `filer.enable` and `s3.enable`.

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/seaweedfs_test.nix>
