# Changelog for services-flake

## 0.4.0 (Dec 10, 2024)

✨ This release introduces two new services and includes bug fixes for existing ones.

### 🚀 New Services

- **mongodb** (by @greg-hellings in https://github.com/juspay/services-flake/pull/339)
- **memcached** (by @secobarbital in https://github.com/juspay/services-flake/pull/314)

### 🛠️ Miscellaneous features & fixes

- **devShell**: Export packages of enabled services (by @shivaraj-bh in https://github.com/juspay/services-flake/pull/355). See [documentation](https://community.flake.parts/services-flake/devshell) for usage.
- **redis**: Support using Unix socket (by @shivaraj-bh in https://github.com/juspay/services-flake/pull/353 and https://github.com/juspay/services-flake/issues/365). See [documentation](https://community.flake.parts/services-flake/redis#unix-socket).
- Add `max_restarts` to all services to avoid restarting indefinitely (by @shivaraj-bh in https://github.com/juspay/services-flake/pull/311)
- **grafana**: Add `declarativePlugins` option (by @conscious-puppet in https://github.com/juspay/services-flake/pull/356)
- **clickhouse-init**: kill `clickhouse-server` on EXIT (by @shivaraj-bh in https://github.com/juspay/services-flake/pull/385)
- **postgres**: Move `pg_ctl stop` to trap during init (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/eb239b01894f58fd3f578ff2623e6d7b3509f783)
- **postgres**: include `find` in `runtimeInputs` of setup script  (by @dzmitry-lahoda in https://github.com/juspay/services-flake/pull/340)
- **elasticsearch**: Fixed permission to add to directories in elasticsearch plugins (by @secobarbital in https://github.com/juspay/services-flake/pull/332)


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

- **mysql**: allow configuring socketDir on mysql. if not provided, uses dataDir as default (by @attilaersek in #172)
- **dev**: add `just changelog` (by @shivaraj-bh in #162)
- **postgres**: add connectionURI option (by @shivaraj-bh in #143)
- add pre-commit-hooks.nix, enforcing conventional commits (by @shivaraj-bh in #121)

### Fix

- **mysql**: use absolute socket path in configureTimezones (by @attilaersek in #170)
- **postgres**: fix pg_isready issue with empty listen_addresses (by @johnhampton in #165)
- **grafana**: add `coreutils` as runtimeInput for the startScript (by @shivaraj-bh in #164)
- **pgadmin**: Fix pgadmin scripts on MacOS (by @Javyre in #163)
- **test**: grafana on darwin is no longer broken in upstream (by @shivaraj-bh in #161)
- **postgres**: empty `socketDir` by default (by @shivaraj-bh in #160)
- **mysql**: look for `*.sql` files in the top-level schema directory (by @shivaraj-bh in #154)
- **template**: Was broken in previous PR merge (by @srid in https://github.com/juspay/services-flake/commit/1c6e8fc86792e31abe719968f3a50e43f2508854)

### Refactor

- **deprecation**: replace types.string with types.str (by @shivaraj-bh in https://github.com/juspay/services-flake/commit/423b85482dc193fecd6d49f777ee57b344cf2b72)
- writeShellScriptBin -> writeShellApplication (by @shivaraj-bh in #155)
- **postgres**: replace string argument with attrset for `connectionURI` (by @shivaraj-bh in #146)
- **example**: remove unused pg2 service (by @shivaraj-bh in #142)

## 0.1.0 (Mar 6, 2024)

- Initial release
