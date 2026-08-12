# Configuration

AppPilot v0.1 stores user configuration under `~/.config/apppilot` by default.

## Main Config

```yaml
version: 1

server:
  name: local

defaults:
  output: human
```

## PM2 Application

```yaml
name: users-api
manager: pm2
path: /home/user/apps/users-api
entrypoint: dist/main.js
environment: production
```

## Docker Compose Application

```yaml
name: ecommerce
manager: compose
path: /home/user/apps/ecommerce
compose_file: compose.yaml
environment: production
```

## Validation

Application names must be alphanumeric with optional `_` or `-`. Paths must be absolute and must not contain traversal. PM2 entrypoints and Compose files are relative to the application path and must exist.
