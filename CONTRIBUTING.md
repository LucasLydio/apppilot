# Contributing

Thanks for helping AppPilot become boringly reliable.

For v0.1, keep changes focused on the CLI contract in `apppilot-v0.1-build-guide.md`.

Before opening a pull request:

```bash
shellcheck bin/apppilot src/**/*.sh install.sh uninstall.sh tests/test_helper.bash
bats tests/unit/cli.bats tests/unit/registry.bats
```

Guidelines:

- Keep command files thin.
- Put manager-specific logic in adapters.
- Keep JSON output deterministic.
- Use stable exit codes from `src/core/exit-codes.sh`.
- Do not add automatic server-hardening or deployment features to v0.1.
