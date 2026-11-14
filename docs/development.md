# Development

## Versioning

Semantic versions as git tags (`vMAJOR.MINOR.PATCH`), each listed in [CHANGELOG.md](../CHANGELOG.md). New feature: minor. Fix: patch. Change that needs manual steps on existing machines: major.

Current version: `git -C ~/dotfiles describe --tags`

## Checks

- WT merge logic: `python3 -I windows/terminal/test_merge.py`
- Windows installer helpers: `powershell -ExecutionPolicy Bypass -File windows\test_install.ps1`
