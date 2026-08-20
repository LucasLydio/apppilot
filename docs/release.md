# Release Checklist

Use this checklist before tagging `v0.1.0`.

## Automated Checks

- [ ] ShellCheck passes
- [ ] Unit tests pass
- [ ] CLI smoke tests pass
- [ ] JSON output validates with `jq`
- [ ] Integration tests pass or skips are documented

Commands:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh tests/test_helper.bash
bats tests/unit/cli.bats tests/unit/registry.bats
```

## Manual VM Or WSL Checks

- [ ] Fresh clone into `~/projects/apppilot`
- [ ] `./install.sh` installs into `~/.local`
- [ ] `apppilot init` renders the welcome UI
- [ ] `apppilot doctor` runs without crashing
- [ ] `apppilot security audit` is read-only
- [ ] `apppilot adapters list` shows Git, PM2, and Compose
- [ ] `apppilot adapters list` shows Nginx and Certbot
- [ ] `apppilot adapters install git --dry-run` is clear
- [ ] `apppilot adapters install nginx --dry-run` is clear
- [ ] `apppilot adapters install certbot --dry-run` is clear
- [ ] `apppilot adapters install pm2 --dry-run` is clear
- [ ] `apppilot adapters install compose --dry-run` is clear

## Real App Checks

- [ ] Real app cloned outside AppPilot, for example `~/apps/tiny-api`
- [ ] `apppilot clone <repo> <name> --dry-run` shows the destination and next step
- [ ] Guided `apppilot add` shows tips and defaults
- [ ] Guided `apppilot add` can redo answers with `r`
- [ ] `apppilot add-static --name <app> --path <path> --build-dir dist` registers a frontend build folder
- [ ] `.env.example` prompt can create `.env`
- [ ] `apppilot env init <app>` works for an already-registered app
- [ ] `apppilot env init <app>` refuses to overwrite `.env`
- [ ] `apppilot start <app>` works for PM2 when PM2 is installed
- [ ] `apppilot deploy <app> --dry-run` shows `git pull origin main`
- [ ] `apppilot deploy <app>` runs tests before build when a test script exists
- [ ] Failed tests stop deploy before build and restart
- [ ] `apppilot deploy history <app>` shows the latest deploy records
- [ ] `apppilot deploy rollback <app> --dry-run` shows the target revision
- [ ] `apppilot deploy rollback <app>` resets Git and restarts the app
- [ ] `apppilot expose <static-app> --domain <domain> --dry-run` shows Nginx static config
- [ ] `apppilot expose <app> --domain <domain> --type proxy --port 3000 --dry-run` shows Nginx proxy config
- [ ] `apppilot health <app>` checks runtime status
- [ ] `apppilot health <app> --url <url>` checks HTTP response
- [ ] `apppilot backup snapshot <app> --dry-run` shows backup exclusions
- [ ] `apppilot backup snapshot <app>` creates a snapshot archive
- [ ] `apppilot backup list <app>` shows snapshot archives
- [ ] `apppilot status <app>` table is aligned
- [ ] `apppilot status <app> --full` shows details
- [ ] `apppilot logs <app> --lines 50` works

## Documentation Checks

- [ ] README VM setup path is accurate
- [ ] README terminal screenshots match current output closely
- [ ] Commands doc includes `env init`
- [ ] Configuration doc explains `~/projects`, `~/apps`, and AppPilot config paths
- [ ] Security doc explains `.env`, `.env.example`, and secrets boundaries
- [ ] No committed `.env` files
- [ ] `CHANGELOG.md` updated
- [ ] `SECURITY.md` updated

## Release

```bash
git tag v0.1.0
git push origin v0.1.0
```

Use `v0.1.x` patch releases for hardening, compatibility fixes, documentation fixes, and tests.
