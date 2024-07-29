# Changelog for services-flake

## 0.3.0 (Jul 29, 2024)

This release introduces new services, primarily focused on [running AI chatbots locally](https://community.flake.parts/services-flake/llm) 🤖. It also includes a few non-breaking fixes and refactors 🔄 to promote DRY (Don’t Repeat Yourself) principles when adding new services.

### 🚀 New Services


- **Tika** (by @drupol in https://github.com/juspay/services-flake/commit/f041f87b27cdcb70af2030ee16516356c16691f2)
- **Searxng** (by @drupol in #241)
- **Open WebUI** (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/e7eb9dec416765b09261f699c84988cfc0e02079)
- **Ollama** (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/d84efa4788d285eab44ce1b1e6422e06694420ab)
- **Weaviate** (by @jedimahdi in #195)
- **Tempo** (by @tim-smart in #192)

### 🛠️ Miscellaneous features & fixes

- **tika**: add `enableOcr` option (by @drupol in #275)
- Allow overriding namespace + make default namespace fully qualified (by @srid in #258)
- **grafana**: add providers configuration (by @alexpearce in #211)
- **ollama**: `kernelPackages` are irrelevant on non-NixOS distributions (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/8145ba10cb02dc0a843bba371fc2d42cea7fd226)
- **ollama**: Broken `dataDir` convention; Allow ENVs in `dataDir` (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/db7ab711d9a6cefd28dbcfe58409d3a968a3b713)
- **postgres**: stop init on error in `sql` scripts (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/12e74823f4f316530c05453df572cddc88a04b1d)
- **nginx**: link nginx.conf to dataDir (by @szucsitg in #173)

### 🔄 Refactors

- Move services under `./nix/services` (by @srid in #262)
- Do not repeat `enable` option (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/ea3a18a991fd5e0df3543f17c9209a6942068c4a)
- Do not repeat `dataDir` (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/dfcdbbca0213cb0b7d4839145c3466f73073c207)

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
