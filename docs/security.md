# Security

AppPilot v0.1 audits and reports. It does not automatically modify server security settings.

## Audit Checks

`apppilot security audit` checks:

- SSH root login and password authentication configuration where readable
- UFW or firewalld presence and active state
- Published Docker container ports, with warnings for commonly sensitive services
- AppPilot secrets directory and secret file permissions

## Boundaries

The audit is not a full security assessment. It gives useful signals for review without claiming the server is safe.

AppPilot avoids unnecessary `sudo` and does not require running the entire CLI as root. Some audit checks may be limited by the current user's permissions.

Sensitive data should be kept outside application registry files. Commands must not print secret values in human output, JSON output, logs, or errors.
