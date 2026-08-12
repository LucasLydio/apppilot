# AppPilot

AppPilot is an open-source DevOps CLI for Linux VPS environments.

It gives you one predictable command surface for common host and application operations, even when different apps are managed by different tools such as PM2 or Docker Compose.

AppPilot v0.1 is intentionally small. It proves the foundation:

- Inspect a Linux host
- Initialize local AppPilot configuration
- Register multiple applications
- Manage PM2 applications
- Manage Docker Compose applications
- Run diagnostics
- Run audit-only security checks
- Print human-readable output
- Print JSON for scripts, CI, and AI agents
- Support dry-run and non-interactive execution

AppPilot does not replace PM2 or Docker. It orchestrates them through a safer and more consistent CLI.

## Status

This project is currently v0.1.

Supported now:

- Ubuntu and Debian-oriented Linux host detection
- User-local installation
- Application registry files
- PM2 adapter
- Docker Compose adapter
- Built-in adapter status with `apppilot adapters list`
- `apppilot doctor`
- `apppilot security audit`
- JSON output with `--json`
- Dry-run behavior for mutating commands
- Non-interactive mode for automation
- ShellCheck, Bats, and GitHub Actions

Not included in v0.1:

- Automatic firewall changes
- Automatic SSH hardening
- SSL provisioning
- Nginx configuration
- Git deployment pipelines
- Backups and restores
- Rollbacks
- Monitoring dashboards
- Plugins
- Kubernetes
- systemd applications

Those belong to later versions.

## Install

Clone the project inside your Linux environment or VPS:

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/LucasLydio/apppilot.git
cd apppilot
```

Install AppPilot for your current Linux user:

```bash
chmod +x install.sh bin/apppilot
./install.sh
```

The installer creates:

```text
~/.local/bin/apppilot
~/.local/share/apppilot/
~/.config/apppilot/
~/.local/state/apppilot/
```

Make sure `~/.local/bin` is on your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
apppilot --version
apppilot doctor
```

During development you can also run the CLI directly from the repository:

```bash
bash bin/apppilot --help
```

## Quick Start

Initialize AppPilot:

```bash
apppilot init
```

Inspect the host:

```bash
apppilot doctor
```

Validate AppPilot configuration and registered apps:

```bash
apppilot validate
```

Run the security audit:

```bash
apppilot security audit
```

Show built-in adapters and dependency status:

```bash
apppilot adapters list
```

Install missing adapter dependencies explicitly:

```bash
apppilot adapters install --dry-run
apppilot adapters install pm2
apppilot adapters install compose
```

List registered applications:

```bash
apppilot list
```

## Register Applications

AppPilot keeps one small YAML file per application under:

```text
~/.config/apppilot/apps/
```

### PM2 App

Example project:

```text
/srv/users-api/
  dist/main.js
```

Register it:

```bash
apppilot add \
  --name users-api \
  --manager pm2 \
  --path /srv/users-api \
  --entrypoint dist/main.js \
  --non-interactive
```

This creates:

```yaml
name: users-api
manager: pm2
path: /srv/users-api
entrypoint: dist/main.js
environment: production
```

Manage it:

```bash
apppilot start users-api
apppilot status users-api
apppilot restart users-api
apppilot logs users-api --lines 100
apppilot stop users-api
```

PM2 processes use deterministic names:

```text
apppilot-users-api
```

### Docker Compose App

Example project:

```text
/srv/ecommerce/
  compose.yaml
```

Register it:

```bash
apppilot add \
  --name ecommerce \
  --manager compose \
  --path /srv/ecommerce \
  --compose-file compose.yaml \
  --non-interactive
```

Manage it:

```bash
apppilot start ecommerce
apppilot status ecommerce
apppilot restart ecommerce
apppilot logs ecommerce
apppilot stop ecommerce
```

## Automation

Use `--json` when another tool needs to consume the output:

```bash
apppilot doctor --json
apppilot list --json
apppilot status users-api --json
apppilot security audit --json
apppilot adapters list --json
```

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

Use `--non-interactive` in scripts and CI:

```bash
apppilot restart users-api --non-interactive
```

Use `--dry-run` before changing state:

```bash
apppilot init --dry-run
apppilot add --name users-api --manager pm2 --path /srv/users-api --entrypoint dist/main.js --dry-run --non-interactive
apppilot restart users-api --dry-run
apppilot remove users-api --dry-run
```

Dry-run commands validate inputs and describe planned actions without making changes.

## Command Reference

```bash
apppilot --help
apppilot --version

apppilot init

apppilot add --name <name> --manager <pm2|compose> --path <path> [--entrypoint <file>|--compose-file <file>]
apppilot remove <app> --yes
apppilot list

apppilot start <app>
apppilot stop <app>
apppilot restart <app>
apppilot status <app>
apppilot logs <app> [--lines <n>]

apppilot doctor
apppilot security audit
apppilot adapters list
apppilot adapters install [pm2|compose|all] [--yes]
apppilot adapters updates
apppilot validate
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

## Project Layout

```text
bin/apppilot              CLI entrypoint
src/commands/            Public command handlers
src/core/                Config, registry, output, locks, exit codes
src/host/                Host, resources, packages, and port inspection
src/adapters/            PM2 and Docker Compose adapters
src/security/            Audit-only security checks
tests/unit/              Bats unit tests
tests/integration/       PM2 and Compose integration tests
docs/                    Architecture and reference docs
```

The command files stay thin. Manager-specific behavior belongs in adapters.

## Adapters

In v0.1, AppPilot has built-in adapters for PM2 and Docker Compose. It does not have third-party installable plugins yet.

The `adapters` command reports the built-in adapters and whether their required system tools are available:

```bash
apppilot adapters list
apppilot adapters list --json
```

Example:

```text
Name         Type       Status     Required commands
pm2          adapter    missing    pm2
compose      adapter    partial    docker, docker compose
```

Status values:

- `installed`: required command support is available
- `partial`: Docker exists, but `docker compose` is unavailable
- `missing`: required command support is unavailable

`apppilot init` does not install PM2, Docker, or Docker Compose. It only creates AppPilot configuration and state directories.

Install adapter dependencies explicitly:

```bash
apppilot adapters install --dry-run
apppilot adapters install pm2
apppilot adapters install compose
apppilot adapters install all --yes --non-interactive
```

Default behavior:

- `apppilot adapters install` installs dependencies for adapters that are missing or partial.
- `apppilot adapters install pm2` installs Node/npm requirements and PM2.
- `apppilot adapters install compose` installs Docker Engine and the Docker Compose plugin.
- `apppilot adapters install all` attempts both adapters.

Safety behavior:

- Install commands support `--dry-run`.
- Install commands require confirmation unless `--yes` is passed.
- `--non-interactive` install commands require `--yes`.
- System package installation currently supports Ubuntu/Debian with `apt`.
- Docker installation uses Docker's official apt repository and GPG key, not `curl | bash`.
- PM2 installation installs Node.js LTS from the NodeSource apt repository when Node/npm are missing or too old.
- PM2 installation requires Node.js LTS 18+ before PM2 is installed.
- The default Node.js LTS major can be overridden with `APPPILOT_NODE_LTS_MAJOR`.

Check adapter updates:

```bash
apppilot adapters updates
apppilot adapters updates --json
```

## Development

Install development dependencies on Ubuntu or WSL:

```bash
sudo apt update
sudo apt install -y shellcheck bats jq
```

Run static checks:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh
```

Run unit tests:

```bash
bats tests/unit/cli.bats tests/unit/registry.bats
```

Run CLI smoke checks manually:

```bash
tmp="$(mktemp -d)"
export APPPILOT_CONFIG_HOME="$tmp/config"
export APPPILOT_STATE_HOME="$tmp/state"

bash bin/apppilot --version
bash bin/apppilot init --non-interactive
bash bin/apppilot list --json
bash bin/apppilot validate --json
bash bin/apppilot doctor --json
bash bin/apppilot security audit --json
```

Run integration tests only when the required tools are installed and running:

```bash
bats tests/integration
```

PM2 integration tests require `pm2`.

Docker Compose integration tests require Docker, a running Docker daemon, and modern `docker compose`.

## Contributing Rules

Before opening a pull request:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh
bats tests/unit
```

Contribution guidelines:

- Keep v0.1 focused on the documented scope.
- Keep `bin/apppilot` as a router, not an implementation bucket.
- Keep command files thin.
- Put PM2 and Docker Compose logic in adapters.
- Do not use `eval`.
- Quote shell variables.
- Validate application names and paths.
- Keep JSON output deterministic.
- Never print secrets.
- Use exit codes from `src/core/exit-codes.sh`.
- Add or update tests for behavior changes.
- Run `apppilot validate` before relying on registered application state.
- Do not add automatic SSH, firewall, SSL, Nginx, backup, or deployment automation to v0.1.

## Documentation

More details:

- [Architecture](docs/architecture.md)
- [Commands](docs/commands.md)
- [Configuration](docs/configuration.md)
- [Security](docs/security.md)
- [Release Checklist](docs/release.md)
- [Contributing](CONTRIBUTING.md)

## License

AppPilot is released under the license in [LICENSE](LICENSE).
