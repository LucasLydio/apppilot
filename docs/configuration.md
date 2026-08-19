# Configuration

AppPilot stores its own configuration separately from the applications it manages.

Recommended layout:

```text
~/projects/apppilot       AppPilot source code
~/apps/tiny-api           Real application
~/.config/apppilot        AppPilot configuration
~/.local/state/apppilot   AppPilot runtime state
```

Tip: do not put real applications inside the AppPilot repository. Clone app projects into `~/apps` on WSL or a personal VPS. On a shared production server, `/srv/<app>` is also common.

## AppPilot Paths

Default config:

```text
~/.config/apppilot/
  apppilot.yml
  apps/
  secrets/
```

Default state:

```text
~/.local/state/apppilot/
  locks/
  deployments/
  backups/
```

`deployments/` stores deploy history used by `apppilot deploy history <app>` and the default target for `apppilot deploy rollback <app>`.

`backups/` stores app snapshot archives created by `apppilot backup snapshot <app>`.

Tests and automation can override these paths:

```bash
export APPPILOT_CONFIG_HOME="$(mktemp -d)/config"
export APPPILOT_STATE_HOME="$(mktemp -d)/state"
```

## Main Config

Created by `apppilot init`:

```yaml
version: 1

server:
  name: local

defaults:
  output: human
```

## Application Registry Files

AppPilot creates one small YAML file per registered app:

```text
~/.config/apppilot/apps/tiny-api.yml
```

PM2 example:

```yaml
name: tiny-api
manager: pm2
path: /home/lucaslydio/apps/tiny-api
entrypoint: server.js
environment: production
```

Docker Compose example:

```yaml
name: ecommerce
manager: compose
path: /home/lucaslydio/apps/ecommerce
compose_file: compose.yaml
environment: production
```

Tip: registry files must not contain secret values. Put app secrets in the app's `.env` file or another secret store.

## Environment Files

If a project has `.env.example`, AppPilot can create `.env`:

```bash
apppilot env init tiny-api
```

The generated file starts as a copy of `.env.example`. Edit it before restarting the app:

```bash
nano /home/lucaslydio/apps/tiny-api/.env
apppilot restart tiny-api
```

`env init` refuses to overwrite an existing `.env`.

## Validation Rules

Application names:

```text
letters, numbers, underscores, and dashes
must start with a letter or number
maximum 63 characters
```

Paths:

```text
project path must be absolute
project path must already exist
entrypoint and compose file must be relative to the project path
paths must not contain ..
```

Validate anytime:

```bash
apppilot validate
apppilot validate --json
```
