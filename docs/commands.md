# Commands

## Global Flags

```bash
--json
--quiet
--non-interactive
--dry-run
```

## Core

```bash
apppilot --help
apppilot --version
apppilot init
apppilot overview
```

## Registry

```bash
apppilot add
apppilot add --name users-api --manager pm2 --path /srv/users-api --entrypoint dist/main.js --env-from-example --non-interactive
apppilot add --name users-api --manager pm2 --path /srv/users-api --entrypoint dist/main.js --non-interactive
apppilot add --name ecommerce --manager compose --path /srv/ecommerce --compose-file compose.yaml --non-interactive
apppilot list
apppilot remove users-api --yes --non-interactive
```

Run `apppilot add` in a terminal for the guided registration flow. AppPilot asks for the app name, manager, project path, app file, and environment. If `.env.example` exists and `.env` does not, AppPilot can create `.env` from the example before registration. Choose `r` at the confirmation prompt to redo the answers.

## Operations

```bash
apppilot start users-api
apppilot stop users-api
apppilot restart users-api
apppilot status users-api
apppilot status users-api --full
apppilot logs users-api --lines 100
```

## Diagnostics And Audit

```bash
apppilot doctor
apppilot security audit
apppilot adapters list
apppilot adapters install [pm2|compose|all] [--yes]
apppilot adapters updates
apppilot validate
```

## Exit Codes

```text
0  Success
1  Generic failure
2  Invalid arguments
3  Application not found
4  Missing dependency
5  Permission denied
6  Invalid configuration
7  Unsupported operation
8  Health check failed
9  Operation already locked
```
