# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`jetdocker` is a Bash wrapper around `docker compose`, opinionated for PHP development (WordPress, Magento, Symfony) at JETPULP. This repository is both the source repo AND a live install (`~/.jetdocker`, referenced by the `$JETDOCKER` env var): any local edit immediately affects every project using jetdocker on this machine.

**Requires bash 4+** (macOS ships bash 3 — installed via Homebrew here). Scripts are written for bash, not zsh.

## Commands

There is no build, lint, or test suite. Verification is manual:

```bash
bash -n jetdocker.sh plugins/*.sh    # syntax check
shellcheck plugins/up.sh             # ad-hoc lint (some rules disabled inline via shellcheck disable=...)
```

To test a change end-to-end, run jetdocker from a real project directory (one containing a `docker/` config dir):

```bash
jetdocker -D up -s     # -D global flag = debug logging (Log calls become visible)
jetdocker --help       # lists all registered commands
```

Beware of the **daily auto-update**: on the first run of each day, `jetdocker.sh` runs `git pull --rebase origin master` on this repo (flag file `/tmp/jetdocker`). Uncommitted local changes can therefore collide with an incoming rebase mid-test.

## Architecture

### Boot sequence (`jetdocker.sh`)

1. Sources `lib/oo-bootstrap.sh` — the [Bash OO Framework](https://github.com/niieani/bash-oo-framework), providing `import`, `namespace`, `Log`/`Log::AddOutput`, `try { } catch { }`, and `UI.Color.*`. The `try/catch` blocks are alias-based magic: keep the exact `try {` / `} catch {` brace formatting.
2. Sources all plugins: `$JETDOCKER_CUSTOM/jetdocker.sh`, then `$JETDOCKER_CUSTOM/plugins/*.sh`, then `plugins/*.sh`. Deduplication is by **filename**: a custom plugin named like a core one (e.g. `custom/plugins/database-backup.sh`) fully replaces it. `JETDOCKER_CUSTOM` defaults to `./custom` (JETPULP overrides live there, gitignored except examples).
3. Parses global options (`-c` config path, `-D` debug), resolves `$DOCKER_COMPOSE` (`docker compose` vs legacy `docker-compose`), triggers the daily auto-update.
4. Dispatches the command: standalone commands (`update`, `free-disk-space`) run immediately; all others first go through `Jetdocker::CheckProject` then `Jetdocker::GenerateSSLCertificate`.

### Plugin/command registration

Each `plugins/*.sh` file registers commands in global associative arrays:

```bash
COMMANDS['up']='Up::Execute'          # command name -> function
COMMANDS_USAGE['00']="  up ..."       # numeric key = sort order in --help
COMMANDS_STANDALONE['update']=...     # skips project check + SSL cert generation
```

Commands: `up` (up.sh), `term`, `compose`, `cp`, `search-replace-db`, `phpmyadmin`, `free-disk-space`, `symfony-restart`, `update` (in jetdocker.sh). `database-backup.sh` registers no command — only the `DatabaseBackup::Fetch` / `DatabaseBackup::ReplaceInDumpFile` hooks (no-ops here, overridden in the JETPULP custom plugin).

### Per-project contract

`Jetdocker::CheckProject` cd's into the project's config dir (default `./docker`, option `-c`), requires a compose file (`compose.yaml`/`.yml` or `docker-compose.yaml`/`.yml`) and an `env.sh` that **must define an `init()` function**. `env.sh` sets `COMPOSE_PROJECT_NAME` (required), `SERVER_NAME`/`VIRTUAL_HOST`, `MYSQL_DATABASE`, `DB_RESTORE_TIMEOUT`, `SEARCH_AND_REPLACE`, `SYMFONY_PORT`, etc.

Projects customize behavior by **overriding hook functions in `env.sh`**: `Up::Install`, `Up::InstallBeforeStartUp` / `Up::InstallAfterStartUp`, `Up::ExportEnv`, `Up::Message`, `Up::StartLocalApp`, `Compose::DeleteDataVolumes`, `Compose::InitExtraDataVolumes`, `DatabaseBackup::Fetch`... Old kebab-case function names (`install`, `delete-data-volumes`, `init-data-containers`) are kept as BC aliases — don't remove them.

OS overlays are auto-added on top of the base compose file when present: `docker-compose-osx.yml` on macOS, `docker-compose-arm64.yml` on Apple Silicon. On arm64, `DOCKER_DEFAULT_PLATFORM=linux/amd64` is exported globally (images not all available in arm64), except nginx which runs native arm64.

### `up` flow (the core path)

`Up::Execute` → `Compose::InitDockerCompose` (start shared mailhog; `Compose::CheckOpenPorts` auto-raises `DOCKER_PORT_*` to the next free port so several projects can run concurrently; offer to add `VIRTUAL_HOST` to `/etc/hosts`; init data volumes; daily `compose pull`) → `compose up -d $JETDOCKER_UP_DEFAULT_SERVICE` → `Up::StartReverseProxy` → hooks → `compose logs --follow` (unless `-s`).

**Reverse proxy**: a shared `nginx-reverse-proxy` container (ports 80/443) plus `nginx-reverse-proxy-gen` (jwilder/docker-gen, **pinned by sha256 digest** — see commit b4ec260) regenerate nginx config from running containers' `VIRTUAL_HOST` env var. Both containers are destroyed and recreated on every `up`. The nginx template is heredoc-inlined in `Up::StartReverseProxy` (plugins/up.sh).

**Database restore**: on first `up` (or after `-d/--delete-data`), the `<project>-dbdata` volume is created, `DatabaseBackup::Fetch` downloads a dump into `docker/db/` (executed by the DB image's entrypoint in alphabetical order), readiness is awaited via the `await` binary with `DB_RESTORE_TIMEOUT`, then Search Replace DB runs if a `search-replace-db` service exists in the compose file. If the compose config declares a `healthcheck`, jetdocker skips its own DB start/wait.

**SSL**: a wildcard cert for `*.$JETDOCKER_DOMAIN_NAME` (default `localhost.tv`) signed by `cacerts/jetdockerRootCA.crt` lives in the `jetdocker-ssl-certificate` docker volume, mounted in the nginx proxy. The volume is only regenerated if its label doesn't match the current domain — to force regeneration, remove the volume (see the "Renouveler le certificat SSL" procedure in the user's global instructions).

### Other directories

- `lib/` — vendored Bash OO Framework (`util/`, `UI/`, `Array`, `String`, ...). Don't modify; it's framework code.
- `examples/` — ready-to-use `docker/` config dirs per stack (wordpress, magento, magento2, symfony, symfony4); serve as templates and as reference for the env.sh contract.
- `tools/install.sh` — curl-able installer (checks prerequisites, clones repo, sets `$JETDOCKER`).
- `templates/jetdockerrc` — template for `~/.jetdockerrc` (sourced by the shell, sets `JETDOCKER`, `USER_UID`/`USER_GROUP`; `JETDOCKER_DOMAIN_NAME` can be overridden there).
- `bash_home/` — mounted as home in containers (`.bash_history`, `.my_aliases` persist across container recreation); gitignored except `.bashrc`.
- `docker-compose.yml` (repo root) — the shared mailhog service only.

## Conventions

- Functions are namespaced `Plugin::FunctionName`; each command entry point starts with `namespace x` + `${DEBUG} && Log::AddOutput x DEBUG` and parses its own options with `getopts` (short options plus a `-:` branch for long options).
- User-facing output goes through `echo` with `$(UI.Color.*)`; diagnostic output goes through `Log` (visible only with `-D`).
- French comments appear in places; keep new comments in English.
