# Changelog for services-flake

## Unreleased

### Feat

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
- overlays for packages in test flake (#120)

## 0.1.0 (Mar 6, 2024)

- Initial release
