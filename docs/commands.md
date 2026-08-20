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
apppilot adapters install git
apppilot adapters install nginx
apppilot adapters install certbot
apppilot adapters install pm2
apppilot adapters install compose
apppilot adapters install all --yes --non-interactive
apppilot adapters updates
```

Tip: Git is required for clone and deploy. Nginx is required for `expose`, and Certbot is required only when using `expose --ssl`. Use PM2 for Node apps with an entrypoint such as `server.js` or `dist/main.js`. Use Compose for projects with `compose.yaml` or `docker-compose.yml`.

## Clone

```bash
apppilot clone https://github.com/example/tiny-api.git tiny-api
apppilot clone https://github.com/example/tiny-api.git tiny-api --branch main
apppilot clone https://github.com/example/tiny-api.git tiny-api --path /srv/tiny-api
apppilot clone https://github.com/example/tiny-api.git tiny-api --dry-run
```

`clone` creates the project folder, but it does not register the app. After cloning, run:

```bash
cd ~/apps/tiny-api
apppilot add
```

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

Static frontend:

```bash
cd /home/lucaslydio/apps/web
npm run build
apppilot add-static --name web --path "$PWD" --build-dir dist
```

List and remove:

```bash
apppilot list
apppilot remove tiny-api --yes --non-interactive
```

Tip: the project path must already exist. `add` is for PM2 and Compose apps. `add-static` is for frontend build folders served by Nginx.

## Environment Files

Create `.env` from `.env.example` for an already-registered app:

```bash
apppilot env init tiny-api
apppilot env init tiny-api --dry-run
apppilot env init tiny-api --json
```

`env init` refuses to overwrite an existing `.env`.

## Expose With Nginx

Static frontend:

```bash
apppilot expose web --domain example.com --dry-run
apppilot expose web --domain example.com --yes
apppilot expose web --domain example.com --listen-port 8080 --dry-run
```

Backend service:

```bash
apppilot expose api --domain api.example.com --type proxy --port 3000 --dry-run
apppilot expose api --domain api.example.com --type proxy --port 3000 --yes
```

With Certbot:

```bash
apppilot expose web --domain example.com --ssl --email ops@example.com --dry-run
apppilot expose web --domain example.com --ssl --email ops@example.com --yes
```

`expose` writes an Nginx site config, enables it, tests Nginx, and reloads or starts Nginx. It does not edit DNS. `--ssl` runs Certbot after Nginx is configured.

`--listen-port` changes the public port Nginx listens on. Use it when another service, such as Docker, must keep port `80`:

```bash
apppilot expose web --domain example.com --listen-port 8080 --yes
```

Then access the site with the port in the URL:

```text
http://example.com:8080
```

Tip: all enabled Nginx sites must avoid port `80` while another process owns it. If Ubuntu's default Nginx site is enabled, disable that site or it can still prevent Nginx from starting.

Tip: if Nginx says the configuration is valid but reload fails because `/run/nginx.pid` is empty, Nginx was not running cleanly. AppPilot will try to restart or start Nginx after a successful config test.

## Operations

```bash
apppilot start tiny-api
apppilot stop tiny-api
apppilot restart tiny-api
apppilot deploy tiny-api
apppilot deploy tiny-api --dry-run
apppilot deploy tiny-api --remote origin --branch main
apppilot deploy tiny-api --skip-tests
apppilot deploy tiny-api --skip-install
apppilot deploy tiny-api --skip-build
apppilot deploy history tiny-api
apppilot deploy rollback tiny-api --dry-run
apppilot deploy rollback tiny-api
apppilot deploy rollback tiny-api --to <commit-sha>
apppilot expose tiny-api --domain api.example.com --type proxy --port 3000 --dry-run
apppilot health tiny-api
apppilot health tiny-api --url http://localhost:3000
apppilot backup snapshot tiny-api
apppilot backup snapshot tiny-api --include-env
apppilot backup list tiny-api
apppilot status tiny-api
apppilot status tiny-api --full
apppilot logs tiny-api --lines 100
```

`deploy` defaults to `git pull origin main`. If `package.json` has a `test` script, AppPilot runs it before build. If tests fail, deploy stops before build and restart. Use `--skip-tests` only when you intentionally want to bypass tests.

`deploy history` shows the latest deploy records stored by AppPilot. `deploy rollback` uses the previous recorded Git revision by default, runs `git reset --hard`, and restarts the app. It refuses dirty working trees unless you pass `--allow-dirty`. Use `--to <commit-sha>` when you want to rollback to a specific revision.

`health` checks the registered runtime status and can optionally request an HTTP URL. `backup snapshot` creates a `.tar.gz` archive under AppPilot state, excluding `.git`, `node_modules`, and `.env` unless `--include-env` is passed.

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
apppilot deploy history tiny-api --json
apppilot health tiny-api --dry-run --json
apppilot backup snapshot tiny-api --dry-run --json
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
