# Architecture

AppPilot is a control layer for Linux VPS applications.

It owns validation, registry state, command routing, output formatting, and safe orchestration. It does not replace PM2, Docker, Docker Compose, Git, Node, or the application framework.

## Flow

Typical PM2 flow:

```text
git clone app into ~/apps/tiny-api
npm install / npm run build
apppilot add
apppilot env init tiny-api
apppilot start tiny-api
```

When `apppilot start tiny-api` runs, AppPilot:

```text
loads ~/.config/apppilot/apps/tiny-api.yml
validates the app path and entrypoint
resolves the pm2 adapter
runs PM2 with the deterministic runtime name apppilot-tiny-api
```

Typical Compose flow:

```text
git clone app into ~/apps/ecommerce
ensure compose.yaml exists
apppilot add
apppilot env init ecommerce
apppilot start ecommerce
```

## Code Responsibilities

- `bin/apppilot` parses global flags and routes commands.
- `src/commands` contains public command handlers.
- `src/core` owns config paths, registry files, env file helpers, locks, exit codes, and output envelopes.
- `src/adapters` contains PM2 and Docker Compose behavior.
- `src/host` performs Linux host, resource, package, and port inspection.
- `src/security` performs audit-only checks.
- `src/utils` contains JSON, logging, colors, UI helpers, and validators.

## Runtime Data

User-mode configuration:

```text
~/.config/apppilot/
  apppilot.yml
  apps/
  secrets/
```

Runtime state:

```text
~/.local/state/apppilot/
  locks/
```

Application files stay in the application project:

```text
~/apps/tiny-api/
  server.js
  .env.example
  .env
```

## Output Modes

Human output is designed for terminal use and screenshots.

JSON output uses a stable envelope:

```json
{
  "success": true,
  "dryRun": false,
  "data": {},
  "warnings": [],
  "errors": []
}
```

Quiet mode suppresses banners and decoration. Exit codes remain authoritative.

## Boundaries

AppPilot v0.1 deliberately avoids hidden automation:

- It does not clone repositories.
- It does not build applications.
- It does not edit SSH, firewall, Nginx, or SSL configuration.
- It does not overwrite `.env`.
- It does not print secret values.
