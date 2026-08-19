# AppPilot

AppPilot is an open-source DevOps CLI for Linux VPS environments.

It gives small teams and solo developers one predictable command surface for apps managed by PM2 or Docker Compose:

```bash
apppilot doctor
apppilot adapters install pm2
apppilot add
apppilot env init tiny-api
apppilot start tiny-api
apppilot status tiny-api
```

AppPilot does not replace PM2, Docker, Git, or your application framework. It helps you prepare the VM, clone or register apps on the server, and run common operations with safer defaults.

## What v0.1 Does

Supported now:

- User-local installation inside Linux, WSL, or a VPS
- Linux host checks with `doctor`, `overview`, and `security audit`
- Built-in adapters for PM2 and Docker Compose
- Adapter dependency installation with dry-run and confirmation
- Guided application registration with tips and examples
- `.env.example` to `.env` initialization
- Git pull, test, build, and restart with `apppilot deploy`
- PM2 and Compose start, stop, restart, status, and logs
- Human output for terminals and JSON output for scripts
- Bats, ShellCheck, and GitHub Actions test coverage

Not included in v0.1:

- Git clone automation and full deployment pipelines
- Nginx or SSL configuration
- Firewall or SSH auto-hardening
- Backups, rollbacks, dashboards, Kubernetes, or third-party plugins

Those are good candidates for later versions.

## What v0.2 Starts

v0.2 begins with the first project bootstrap command:

```bash
apppilot clone <repo> <name>
```

It clones into `~/apps/<name>` by default, then points the user to `apppilot add` so manager, entrypoint, Compose file, and environment are still reviewed before AppPilot controls the app.

## Recommended VM Layout

Keep AppPilot source code separate from the real apps it manages:

```text
~/projects/apppilot       AppPilot source code
~/apps/tiny-api           A real application
~/apps/ecommerce          Another real application
```

Tip: do not clone apps inside `~/projects/apppilot`. Run `apppilot add` from inside the app folder, not from inside the AppPilot repo.

## Install AppPilot

Clone AppPilot inside your Linux environment:

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/LucasLydio/apppilot.git
cd apppilot
```

Install it for the current Linux user:

```bash
chmod +x install.sh bin/apppilot
./install.sh
```

The installer writes to user-local paths:

```text
~/.local/bin/apppilot
~/.local/share/apppilot/
~/.config/apppilot/
~/.local/state/apppilot/
```

If `apppilot` is not found after install, add `~/.local/bin` to your shell path:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
hash -r
```

Verify:

```bash
apppilot --version
apppilot doctor
```

## First Run

Initialize AppPilot:

```bash
apppilot init
```

Terminal screenshot:

```text
+----------------------------------------------------------+
|    ___              ____  _ _       _                    |
|   / _ \ _ __  _ __ |  _ \(_) | ___ | |_                  |
|  | |_| | '_ \| '_ \| |_) | | |/ _ \| __|                 |
|  |  _  | |_) | |_) |  __/| | | (_) | |_                  |
|  |_| |_| .__/| .__/|_|   |_|_|\___/ \__|                 |
|        |_|   |_|                                         |
|                                                          |
| DevOps control for Linux VPS applications                |
| Safe defaults. Adapter-based operations. JSON-ready.     |
+----------------------------------------------------------+

Initialized
  OK Config                 /home/lucaslydio/.config/apppilot
  OK State                  /home/lucaslydio/.local/state/apppilot

Next Steps
  1. apppilot adapters list
  2. apppilot adapters install pm2 --dry-run
  3. apppilot overview
  4. apppilot doctor

Contribute
  Repository         https://github.com/LucasLydio/apppilot
  Issues             https://github.com/LucasLydio/apppilot/issues
  Feedback           Open an issue with your VPS, app manager, and use case
```

Tip: `apppilot init` only creates AppPilot configuration and state. It does not install PM2, Docker, Docker Compose, Node.js, or clone any app.

## Prepare Adapters

Check what is already installed:

```bash
apppilot adapters list
```

Example:

```text
AppPilot Adapters

  Name           Type                     Status       Required commands
  -------------- ------------------------ ------------ ----------------
  git            source-control           installed    git
  nginx          reverse-proxy            missing      nginx
  certbot        ssl                      missing      certbot
  pm2            process-manager          missing      pm2
  compose        container-orchestrator   partial      docker, docker compose
```

Preview dependency installation:

```bash
apppilot adapters install --dry-run
```

Install what you need:

```bash
apppilot adapters install git
apppilot adapters install nginx
apppilot adapters install certbot
apppilot adapters install pm2
apppilot adapters install compose
```

Tip: adapter installation is explicit. Use PM2 for a Node process with an entry file such as `server.js` or `dist/main.js`. Use Compose when the project already has `compose.yaml` or `docker-compose.yml`.

## Add A Real App

Clone or create your app outside the AppPilot repo:

```bash
mkdir -p ~/apps
cd ~/apps
git clone <your-app-github-url> tiny-api
cd tiny-api
```

Or let AppPilot clone it into the recommended location:

```bash
apppilot clone <your-app-github-url> tiny-api
cd ~/apps/tiny-api
```

Prepare the app like you normally would:

```bash
npm install
npm run build
```

For a tiny PM2 app, the folder might be:

```text
~/apps/tiny-api/
  package.json
  server.js
  .env.example
```

Register it with the guided flow:

```bash
apppilot add
```

Terminal screenshot:

```text
Add Application
Press Enter to accept a value shown in brackets.

Use a short unique app name. Letters, numbers, dashes, and underscores are allowed.
Example: users-api
Name: tiny-api

Choose how AppPilot will manage this project. Use pm2 for Node processes or compose for Docker Compose apps.
Example: pm2
Manager (pm2/compose) [pm2]:

Use the absolute path to the project folder that already exists on this server.
Example: /home/lucaslydio/apps/users-api
Project path [/home/lucaslydio/apps/tiny-api]:

Use the PM2 entry file relative to the project folder. Do not start with '/'.
Example: dist/main.js
Entrypoint [server.js]:

Use a label for this app's runtime environment.
Example: production
Environment [production]:

Found .env.example and no .env. AppPilot can copy it as a starter file with 600 permissions.
Example: .env
Create .env from .env.example? [Y/n] y

Review Application
  Name               tiny-api
  Manager            pm2
  Path               /home/lucaslydio/apps/tiny-api
  Entrypoint         server.js
  Environment        production
  .env               create from .env.example

Register this application? [Y/r/n] y
OK Created .env from .env.example
OK Registered tiny-api (pm2)
```

Tip: values inside brackets are defaults. Press Enter to accept them. For example, `Manager (pm2/compose) [pm2]:` means AppPilot will use `pm2` if you leave it blank.

Tip: if you accidentally type the wrong value, choose `r` at the review prompt to redo the form.

## Environment Files

If an app already has `.env.example`, AppPilot can create `.env` as a starter file:

```bash
apppilot env init tiny-api
nano ~/apps/tiny-api/.env
```

`env init` never overwrites an existing `.env`.

Example for an already-registered app:

```bash
cd ~/apps/tiny-api
cat > .env.example <<'EOF'
PORT=3000
NODE_ENV=production
EOF

apppilot env init tiny-api
nano .env
apppilot restart tiny-api
```

Tip: AppPilot can create the boilerplate file, but you still need to edit real values such as database URLs, tokens, and secrets.

## Run The App

Start the app:

```bash
apppilot start tiny-api
```

Deploy updates from Git, runs tests when a `test` script exists, builds, restarts, and shows status:

```bash
apppilot deploy tiny-api --dry-run
apppilot deploy tiny-api
```

By default deploy pulls from `origin main`. Change that per deploy:

```bash
apppilot deploy tiny-api --remote upstream --branch production
```

Tip: if tests fail, deploy stops before build and restart. Use `--skip-tests` only when you deliberately want to bypass the test step.

Review deploy history or rollback the last deploy:

```bash
apppilot deploy history tiny-api
apppilot deploy rollback tiny-api --dry-run
apppilot deploy rollback tiny-api
```

Rollback uses the previous Git revision recorded by AppPilot, runs `git reset --hard`, and restarts the app. It refuses dirty working trees unless you pass `--allow-dirty`. To choose a specific commit:

```bash
apppilot deploy rollback tiny-api --to <commit-sha>
```

Check status:

```bash
apppilot status tiny-api
```

Terminal screenshot:

```text
AppPilot Status

  ┌────────────────────────┬──────────┬────────────┬──────────┬─────────┬──────────┬──────────┬──────────┬──────────┬────────────────────┐
  │ Name                   │ Manager  │ Status     │ PID      │ CPU     │ Memory   │ Restarts │ Uptime   │ Services │ Target             │
  ├────────────────────────┼──────────┼────────────┼──────────┼─────────┼──────────┼──────────┼──────────┼──────────┼────────────────────┤
  │ tiny-api               │ pm2      │ online     │ 10045    │ 3.2%    │ 63.4M    │ 0        │ 0m       │ -        │ server.js          │
  └────────────────────────┴──────────┴────────────┴──────────┴─────────┴──────────┴──────────┴──────────┴──────────┴────────────────────┘

  Runtime name       apppilot-tiny-api
```

See more details:

```bash
apppilot status tiny-api --full
```

Read logs:

```bash
apppilot logs tiny-api --lines 50
```

Test the app directly if it exposes a port:

```bash
curl http://localhost:3000
```

## Docker Compose Apps

For `manager: compose`, your project needs a real Compose file like a normal Docker project:

```text
~/apps/ecommerce/
  compose.yaml
  Dockerfile
  .env.example
  src/
```

Example `compose.yaml`:

```yaml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    restart: unless-stopped
    env_file:
      - .env
```

Register it:

```bash
cd ~/apps/ecommerce
apppilot add
```

When you choose `compose`, AppPilot starts it with Docker Compose:

```bash
apppilot start ecommerce
apppilot status ecommerce
apppilot logs ecommerce
```

Tip: you only need a `Dockerfile` when your Compose file uses `build: .`. If the Compose file uses an existing image, a Dockerfile is not required.

## Diagnostics

Use these commands after setup:

```bash
apppilot overview
apppilot doctor
apppilot security audit
apppilot validate
```

`security audit` is read-only. It reports SSH, firewall, Docker ports, and AppPilot file permission signals, but it does not change the VM.

## Automation

Use `--json` when another tool needs to consume the output:

```bash
apppilot doctor --json
apppilot list --json
apppilot status tiny-api --json
apppilot security audit --json
apppilot adapters list --json
```

Use `--non-interactive` in scripts and CI:

```bash
apppilot add \
  --name tiny-api \
  --manager pm2 \
  --path /srv/tiny-api \
  --entrypoint server.js \
  --env-from-example \
  --non-interactive
```

Use `--dry-run` before changing state:

```bash
apppilot adapters install pm2 --dry-run
apppilot add --name tiny-api --manager pm2 --path /srv/tiny-api --entrypoint server.js --dry-run --non-interactive
apppilot env init tiny-api --dry-run
apppilot deploy tiny-api --dry-run
apppilot restart tiny-api --dry-run
```

## Command Reference

```bash
apppilot --help
apppilot --version

apppilot init
apppilot overview
apppilot doctor
apppilot security audit
apppilot validate

apppilot adapters list
apppilot adapters install [git|nginx|certbot|pm2|compose|all] [--yes]
apppilot adapters updates

apppilot clone <repo> <name> [--path <destination>] [--branch <branch>]
apppilot add
apppilot add --name <name> --manager <pm2|compose> --path <path> [--entrypoint <file>|--compose-file <file>] [--env-from-example]
apppilot env init <app>
apppilot expose <app> --domain <domain> --type static --build-dir dist [--ssl]
apppilot expose <app> --domain <domain> --type proxy --port 3000 [--ssl]
apppilot list
apppilot remove <app> --yes

apppilot start <app>
apppilot stop <app>
apppilot restart <app>
apppilot deploy <app> [--remote <name>] [--branch <branch>] [--skip-tests] [--skip-install] [--skip-build]
apppilot deploy history <app>
apppilot deploy rollback <app> [--to <commit-sha>] [--allow-dirty]
apppilot health <app> [--url <url>]
apppilot backup snapshot <app> [--include-env]
apppilot backup list <app>
apppilot status <app> [--full]
apppilot logs <app> [--lines <n>]
```

Global flags:

```bash
--json
--quiet
--non-interactive
--dry-run
```

Exit codes:

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

## Development

Install development dependencies on Ubuntu or WSL:

```bash
sudo apt update
sudo apt install -y shellcheck bats jq
```

Run checks:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh tests/test_helper.bash
bats tests/unit/cli.bats tests/unit/registry.bats
```

Run CLI smoke checks manually:

```bash
tmp="$(mktemp -d)"
export APPPILOT_CONFIG_HOME="$tmp/config"
export APPPILOT_STATE_HOME="$tmp/state"

bash bin/apppilot init --non-interactive
bash bin/apppilot overview --json | jq .
bash bin/apppilot list --json | jq .
bash bin/apppilot validate --json | jq .
bash bin/apppilot doctor --json | jq .
bash bin/apppilot security audit --json | jq .
```

## Contributing Rules

Before opening a pull request:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh tests/test_helper.bash
bats tests/unit/cli.bats tests/unit/registry.bats
```

Contribution guidelines:

- Keep v0.1 focused on the documented scope.
- Keep `bin/apppilot` as a router.
- Put PM2 and Docker Compose logic in adapters.
- Use shared helpers for config, registry, env files, locks, output, and validation.
- Do not use `eval`.
- Quote shell variables.
- Validate application names and paths.
- Keep JSON output deterministic.
- Never print secret values.
- Add or update tests for behavior changes.
- Run `apppilot validate` before relying on registered app state.
- Do not add automatic SSH, firewall, SSL, Nginx, backup, or deployment automation to v0.1.

## Documentation

More details:

- [VM Setup Walkthrough](docs/vm-setup.md)
- [Architecture](docs/architecture.md)
- [Commands](docs/commands.md)
- [Configuration](docs/configuration.md)
- [Security](docs/security.md)
- [Release Checklist](docs/release.md)
- [Contributing](CONTRIBUTING.md)

## License

AppPilot is released under the license in [LICENSE](LICENSE).
