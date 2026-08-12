# AppPilot

AppPilot is an open-source DevOps CLI that standardizes application and server operations across Linux VPS environments.

v0.1 is intentionally small. It proves the architecture for safe host inspection, a local application registry, PM2 and Docker Compose adapters, diagnostics, security auditing, structured JSON output, dry-run behavior, and non-interactive automation.

## Install

```bash
./install.sh
apppilot init
```

During development, run directly:

```bash
bash bin/apppilot --help
```

## Commands

```bash
apppilot init
apppilot add --name users-api --manager pm2 --path /srv/users-api --entrypoint dist/main.js --non-interactive
apppilot add --name ecommerce --manager compose --path /srv/ecommerce --compose-file compose.yaml --non-interactive
apppilot list
apppilot status users-api
apppilot restart users-api
apppilot logs users-api
apppilot doctor
apppilot security audit
```

Global flags:

```bash
--json
--quiet
--non-interactive
--dry-run
```

## Current v0.1 Support

- Linux host and resource detection
- User-local configuration in `~/.config/apppilot`
- Runtime locks in `~/.local/state/apppilot`
- PM2 applications
- Docker Compose applications
- Diagnostics with `apppilot doctor`
- Audit-only security checks with `apppilot security audit`
- Stable exit codes and JSON output
- ShellCheck, Bats, and GitHub Actions

## Roadmap

Later versions may add systemd, Nginx, SSL automation, firewall changes, backups, deployment pipelines, rollback, metrics, plugins, databases, and additional runtimes. Those features are not part of v0.1.
