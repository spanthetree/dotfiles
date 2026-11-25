# Development

## Versioning

Semantic versions as git tags (`vMAJOR.MINOR.PATCH`), each listed in [CHANGELOG.md](../CHANGELOG.md). New feature: minor. Fix: patch. Change that needs manual steps on existing machines: major.

Current version: `git -C ~/dotfiles describe --tags`

## Checks

CI runs all of these on every push and pull request ([`.github/workflows/checks.yml`](../.github/workflows/checks.yml)).

- `tests/lint.sh`: the quick ones, in seconds: syntax of every script, shellcheck, `packages.yaml`, the Windows Terminal merge test, PowerShell parsing (with `pwsh`).
- `tests/run.sh`: the installer scenarios in [`tests/scenarios`](../tests/scenarios), each in a fresh `ubuntu:24.04` and `ubuntu:26.04` container (Docker). `tests/run.sh hook` runs one; `-i ubuntu:26.04` one image; `-v` shows everything. Covered: the package lifecycle (apt, GitHub, script, tools, `--check`, removal, `--purge`), the apt removal rules and `apt-deps`, `private:` apps, record migrations, the whole installer (links, backups, `--check`, `--uninstall`), and the pre-commit hook. A new installer feature gets a scenario: see [`tests/lib.sh`](../tests/lib.sh) for the helpers.
- Windows installer helpers: `powershell -ExecutionPolicy Bypass -File windows\test_install.ps1`.
- Secrets: CI runs gitleaks over the whole history.

## Privacy check before commits

The repo is public. `.githooks/pre-commit` (turned on by the installer: `core.hooksPath` in this clone) stops a commit that adds a secret gitleaks recognises, an email address (other than noreply and example ones), or a line matching one of your own patterns in `~/.config/dotfiles/private-patterns`: one extended regex per line, case-insensitive, `#` for comments. Put your name, email, hostnames, employer, internal domains and home IPs there. That file stays on your machine, so the patterns never reach the repo. A checked false alarm: `git commit --no-verify`.
