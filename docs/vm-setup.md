# VM Setup Walkthrough

This walkthrough mirrors the recommended first-run experience for WSL or a small Linux VPS.

## 1. Install AppPilot

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/LucasLydio/apppilot.git
cd apppilot
./install.sh
hash -r
```

Expected command:

```bash
apppilot --version
```

## 2. Initialize AppPilot

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
```

Tip: initialization does not install PM2 or Docker. Use adapters for that.

## 3. Install An Adapter

```bash
apppilot adapters list
apppilot adapters install git --dry-run
apppilot adapters install git
apppilot adapters install nginx --dry-run
apppilot adapters install certbot --dry-run
apppilot adapters install pm2 --dry-run
apppilot adapters install pm2
```

For Docker Compose projects:

```bash
apppilot adapters install compose --dry-run
apppilot adapters install compose
```

## 4. Clone A Real App

Keep applications outside the AppPilot repository:

```bash
mkdir -p ~/apps
cd ~/apps
git clone <your-app-github-url> tiny-api
cd tiny-api
```

Or use AppPilot's v0.2 clone flow:

```bash
apppilot clone <your-app-github-url> tiny-api
cd ~/apps/tiny-api
```

Prepare it normally:

```bash
npm install
npm run build
```

Tip: AppPilot does not clone repositories yet. Clone the app first, then `apppilot deploy <app>` can pull, test, build, and restart it after registration.

## 5. Register The App

```bash
apppilot add
```

Use:

```text
Name: tiny-api
Manager: pm2
Project path: /home/lucaslydio/apps/tiny-api
Entrypoint: server.js
Environment: production
```

If `.env.example` exists, let AppPilot create `.env`, then edit it:

```bash
nano .env
```

For an app already registered before `.env.example` existed:

```bash
apppilot env init tiny-api
nano .env
```

## 6. Start And Inspect

```bash
apppilot start tiny-api
apppilot deploy tiny-api --dry-run
apppilot deploy tiny-api
apppilot status tiny-api
apppilot health tiny-api
apppilot health tiny-api --url http://localhost:3000
apppilot backup snapshot tiny-api --dry-run
apppilot backup snapshot tiny-api
apppilot status tiny-api --full
apppilot logs tiny-api --lines 50
```

Deploy defaults to:

```bash
git pull origin main
```

Use another remote or branch when needed:

```bash
apppilot deploy tiny-api --remote upstream --branch production
```

If `package.json` has a `test` script, deploy runs tests before build. A failed test stops the deploy before build and restart.

Review deploy history:

```bash
apppilot deploy history tiny-api
```

Rollback the last deploy if the new revision is bad:

```bash
apppilot deploy rollback tiny-api --dry-run
apppilot deploy rollback tiny-api
```

Tip: rollback uses the previous Git revision recorded by AppPilot. For a specific commit, run `apppilot deploy rollback tiny-api --to <commit-sha>`.

Rollback refuses dirty working trees by default. Commit, stash, or intentionally pass `--allow-dirty` before resetting a repo with local changes.

If the app exposes a local port:

```bash
curl http://localhost:3000
```

## 7. Diagnose The VM

```bash
apppilot overview
apppilot doctor
apppilot security audit
apppilot validate
```

Tip: `security audit` is read-only. It reports things to review, but it does not change SSH, firewall, Nginx, SSL, or Docker settings.
