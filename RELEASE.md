# Release Notes

## v0.2.0-dev

Focus: make the first real-app setup smoother after the VM is ready.

New commands:

```bash
apppilot clone <repo> <name>
apppilot clone <repo> <name> --path <destination>
apppilot clone <repo> <name> --branch <branch>
apppilot clone <repo> <name> --dry-run
```

New adapter surface:

```bash
apppilot adapters list
apppilot adapters install git
apppilot adapters install nginx
apppilot adapters install certbot
apppilot adapters updates
```

Clone workflow:

```bash
apppilot adapters install git
apppilot clone https://github.com/example/users-api.git users-api
cd ~/apps/users-api
apppilot add
apppilot env init users-api
apppilot deploy users-api --dry-run
```

`clone` does not register the app yet. Registration still uses `apppilot add` so the user can confirm manager, entrypoint, Compose file, and environment.

Infrastructure commands started in v0.2:

```bash
apppilot health <app>
apppilot health <app> --url http://localhost:3000
apppilot backup snapshot <app>
apppilot backup snapshot <app> --include-env
apppilot backup list <app>
```

Release-folder rollback is documented in `docs/v0.2-release-folders.md`. The current rollback command remains Git-reset based until an app is explicitly migrated.

## v0.1.0

Foundation release: local VM/VPS control for apps managed by PM2 or Docker Compose.

Core:

```bash
apppilot --help
apppilot --version
apppilot init
apppilot overview
apppilot doctor
apppilot security audit
apppilot validate
```

Adapters:

```bash
apppilot adapters list
apppilot adapters install pm2
apppilot adapters install compose
apppilot adapters install all --yes --non-interactive
apppilot adapters updates
```

Registry and environment:

```bash
apppilot add
apppilot add --name <name> --manager <pm2|compose> --path <path> [--entrypoint <file>|--compose-file <file>]
apppilot env init <app>
apppilot list
apppilot remove <app> --yes
```

Operations:

```bash
apppilot start <app>
apppilot stop <app>
apppilot restart <app>
apppilot status <app>
apppilot status <app> --full
apppilot logs <app> --lines 100
```

Deploy:

```bash
apppilot deploy <app>
apppilot deploy <app> --remote origin --branch main
apppilot deploy <app> --skip-tests
apppilot deploy <app> --dry-run
apppilot deploy history <app>
apppilot deploy rollback <app>
apppilot deploy rollback <app> --to <commit-sha>
```

Global flags:

```bash
--json
--quiet
--non-interactive
--dry-run
```
