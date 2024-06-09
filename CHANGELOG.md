# Changelog for services-flake

## Unreleased

### Feat

- **grafana**: add providers configuration (#211)
- Add Weaviate service (#195)
- add tempo service (#192)

### Fix

- **postgres**: stop init on error in `sql` scripts
- **nginx**: link nginx.conf to dataDir (#173)

## 0.2.0 (Apr 30, 2024)

### Feat

- **mysql**: allow configuring socketDir on mysql. if not provided, uses dataDir as default. solves #171
- **dev**: add `just changelog` (#162)
- **postgres**: add connectionURI option (#143)
- add pre-commit-hooks.nix, enforcing conventional commits

### Fix

- **mysql**: use absolute socket path in configureTimezones. this fixes #169
- **postgres**: fix pg_isready issue with empty listen_addresses
- **grafana**: add `coreutils` as runtimeInput for the startScript (#164)
- **pgadmin**: Fix pgadmin scripts on MacOS (#163)
- **test**: grafana on darwin is no longer broken in upstream (#161)
- **postgres**: empty `socketDir` by default (#160)
- **mysql**: look for `*.sql` files in the top-level schema directory (#154)
- **template**: Was broken in previous PR merge

### Refactor

- **deprecation**: replace types.string with types.str
- writeShellScriptBin -> writeShellApplication (#155)
- **postgres**: replace string argument with attrset for `connectionURI` (#146)
- **example**: remove unused pg2 service (#142)

## 0.1.0 (Mar 6, 2024)

- Initial release
