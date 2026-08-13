# Commands

This page is the command reference. For the beginner VM walkthrough, start with the README.

## Global Flags

```bash
--json              Print machine-readable JSON
--quiet             Suppress non-essential human output
--non-interactive   Never prompt for input
--dry-run           Show planned mutations without changing state
```

Tip: place global flags before the command for the most predictable behavior. For scripts, prefer `--json --non-interactive`.

## Core

```bash
apppilot --help
apppilot --version
apppilot init
apppilot overview
apppilot validate
```

`apppilot init` creates user-local AppPilot folders. It does not install PM2, Docker, Docker Compose, or clone applications.

## Host Checks

```bash
apppilot doctor
apppilot security audit
```

`doctor` checks host support, resources, dependencies, config, and registered app readability.

`security audit` is read-only. It reports SSH, firewall, Docker port, and AppPilot permission signals without changing the server.

## Adapters

```bash
apppilot adapters list
apppilot adapters install --dry-run
apppilot adapters install pm2
apppilot adapters install compose
apppilot adapters install all --yes --non-interactive
apppilot adapters updates
```

Tip: use PM2 for Node apps with an entrypoint such as `server.js` or `dist/main.js`. Use Compose for projects with `compose.yaml` or `docker-compose.yml`.

## Application Registry

Guided:

```bash
cd ~/apps/tiny-api
apppilot add
```

Non-interactive PM2:

```bash
apppilot add \
  --name tiny-api \
  --manager pm2 \
  --path /home/lucaslydio/apps/tiny-api \
  --entrypoint server.js \
  --env-from-example \
  --non-interactive
```

Non-interactive Compose:

```bash
apppilot add \
  --name ecommerce \
  --manager compose \
  --path /home/lucaslydio/apps/ecommerce \
  --compose-file compose.yaml \
  --env-from-example \
  --non-interactive
```

List and remove:

```bash
apppilot list
apppilot remove tiny-api --yes --non-interactive
```

Tip: the project path must already exist. AppPilot registers and controls apps; v0.1 does not clone or build them.

## Environment Files

Create `.env` from `.env.example` for an already-registered app:

```bash
apppilot env init tiny-api
apppilot env init tiny-api --dry-run
apppilot env init tiny-api --json
```

`env init` refuses to overwrite an existing `.env`.

## Operations

```bash
apppilot start tiny-api
apppilot stop tiny-api
apppilot restart tiny-api
apppilot deploy tiny-api
apppilot deploy tiny-api --dry-run
apppilot deploy tiny-api --remote origin --branch main
apppilot deploy tiny-api --skip-tests
apppilot status tiny-api
apppilot status tiny-api --full
apppilot logs tiny-api --lines 100
```

`deploy` defaults to `git pull origin main`. If `package.json` has a `test` script, AppPilot runs it before build. If tests fail, deploy stops before build and restart. Use `--skip-tests` only when you intentionally want to bypass tests.

PM2 apps are run with deterministic runtime names:

```text
apppilot-<app-name>
```

Compose apps are run with the app name as the Compose project name.

## JSON Examples

```bash
apppilot overview --json
apppilot list --json
apppilot status tiny-api --json
apppilot env init tiny-api --dry-run --json
```

All JSON output uses the stable envelope:

```json
{
  "success": true,
  "dryRun": false,
  "data": {},
  "warnings": [],
  "errors": []
}
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
