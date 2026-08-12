# Security Policy

AppPilot v0.1 is audit-first and conservative. It inspects host and application state, but it does not harden SSH, change firewall rules, install Fail2Ban, provision SSL, or modify Docker networking automatically.

Please report vulnerabilities privately to the project maintainers before public disclosure.

## v0.1 Boundaries

- AppPilot avoids `eval`.
- Application names and paths are validated before use.
- Secret values must never be printed in human output, JSON output, or logs.
- Runtime state is stored outside the repository.
- The security audit reports findings for review; it does not claim complete server security.
