# Release Checklist

Use this checklist before tagging `v0.1.0`.

- [ ] ShellCheck passes
- [ ] Unit tests pass
- [ ] Integration tests pass or documented skips are acceptable
- [ ] WSL test passes
- [ ] Ubuntu test passes
- [ ] Installer tested from a clean environment
- [ ] README commands verified
- [ ] JSON output validated with `jq`
- [ ] No committed secrets
- [ ] Security audit is read-only
- [ ] Dry-run performs no mutations
- [ ] Non-interactive mode never waits for input
- [ ] Stable exit codes documented
- [ ] `CHANGELOG.md` updated
- [ ] `SECURITY.md` updated

Release command:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Use `v0.1.x` patch releases for hardening, compatibility fixes, documentation fixes, and tests.
