# Architecture

AppPilot owns orchestration, not implementation.

It does not replace PM2 or Docker. It validates local configuration, resolves the registered application manager, and invokes the correct adapter through a stable CLI contract.

## Responsibilities

- `bin/apppilot` parses global flags and routes commands.
- `src/core` owns configuration paths, registry files, locks, exit codes, and output envelopes.
- `src/commands` contains thin command handlers.
- `src/adapters` contains manager-specific PM2 and Docker Compose behavior.
- `src/host` performs Linux host, resource, package, and port inspection.
- `src/security` performs audit-only checks.

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

Both paths can be overridden with `APPPILOT_CONFIG_HOME` and `APPPILOT_STATE_HOME`, which tests use to avoid touching real user config.

## Output Modes

Human output is readable and concise. JSON output uses a stable envelope:

```json
{
  "success": true,
  "dryRun": false,
  "data": {},
  "warnings": [],
  "errors": []
}
```

Quiet mode suppresses banners and decoration; exit codes remain authoritative.
