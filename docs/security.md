# Security

AppPilot v0.1 audits and reports. It does not automatically modify server security settings.

## Security Audit

Run:

```bash
apppilot security audit
```

The audit checks:

- SSH root login and password authentication settings where readable
- SSH public-key availability where readable
- UFW or firewalld presence and active state
- Listening TCP ports
- Published Docker container ports, with warnings for commonly sensitive services
- AppPilot config, state, lock, and secrets directory permissions
- AppPilot secret file permissions

Tip: warnings are review prompts, not always failures. For example, a listening HTTP port can be expected on a web server.

## What AppPilot Will Not Do In v0.1

AppPilot will not:

- Disable SSH password authentication
- Enable or change firewall rules
- Configure Nginx
- Issue SSL certificates
- Close ports
- Rewrite Docker Compose files
- Change application secrets

This is intentional. v0.1 should be safe to run while learning what it detects.

## Secrets And Environment Files

AppPilot creates this directory:

```text
~/.config/apppilot/secrets/
```

In v0.1, this directory is checked for permissions but AppPilot does not inject secrets from it into apps.

For real apps today, use the app's own `.env` file or Compose `env_file`:

```text
~/apps/tiny-api/.env
~/apps/ecommerce/.env
```

AppPilot can create `.env` from `.env.example`:

```bash
apppilot env init tiny-api
```

Then edit the real values:

```bash
nano ~/apps/tiny-api/.env
```

Never commit `.env` to Git. Keep `.env.example` safe for public defaults and placeholder values only.

## Permissions

Recommended Linux permissions:

```bash
chmod 600 ~/apps/tiny-api/.env
chmod 700 ~/.config/apppilot/secrets
```

AppPilot attempts to create generated `.env` files with restricted permissions. On native Linux and WSL this should be `600`. Some Windows-mounted filesystems may display different modes.

## Reporting Security Issues

Do not open public issues for sensitive vulnerabilities. Follow the process in the root [SECURITY.md](../SECURITY.md).
