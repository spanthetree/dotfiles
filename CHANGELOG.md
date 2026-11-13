# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org/), tagged `vX.Y.Z`.

## [1.4.1] - 2026-11-13

### Fixed
- `install.sh --packages` refreshes HashiCorp's apt signing key each run (rotated 2026-09), fixing `NO_PUBKEY FC9CA96ACA026560` on `apt-get update`.

## [1.4.0] - 2026-11-13

### Added
- `install.sh --packages`: jq, yq, httpie, cloc, tcptraceroute, whois, bgpq4, socat, ansible (apt); Docker (`docker.io`, `docker-compose-v2`, `docker-buildx`, user added to `docker` group; skipped if Docker is already installed); xh HTTP client, also as `ht`; Claude Code, Codex and OpenCode CLIs.
- Windows: Claude Desktop and OpenCode Desktop (winget), from both `install.ps1` and `install.sh` under WSL.

## [1.3.0] - 2026-11-13

### Added
- `install.ps1` Windows bootstrap: installs Windows Terminal, VS Code, Git, YASB and the Nerd Font; enables WSL2 (resumes after reboot); offers a Debian/Ubuntu distro menu; then runs `install.sh --packages` inside WSL.
- YASB config in `windows/yasb/`, used in place via `YASB_CONFIG_HOME`, autostart on.

## [1.2.2] - 2026-11-13

### Fixed
- `claude`, `uv` and other `~/.local/bin` tools missing in new byobu tabs: PATH moved from `~/.zprofile` to `~/.zshenv`, which every zsh reads.

### Changed
- Byobu tabs start login shells, so `~/.zprofile` runs in each tab. Byobu auto-launch is skipped inside tmux to avoid nesting.

## [1.2.1] - 2026-11-13

### Added
- MIT license.

## [1.2.0] - 2026-11-13

### Added
- Starship prompt: command duration (3s+), background jobs, cached sudo, exit code of failed commands.
- Status row: Kubernetes contexts matching `prod` turn red.
- Byobu browser-style keys: `Ctrl-T` new, `Ctrl-W` close (asks), `Ctrl-PgUp`/`Ctrl-PgDn` prev/next, `Alt-1`..`Alt-9` jump, `Alt-D` fuzzy tab search popup. `Ctrl-T`/`Ctrl-W` pass through to vim.
- Byobu `Ctrl-F7` toggles logging the pane to `~/logs/`.
- Session save/restore across WSL restarts: tmux-resurrect + tmux-continuum (autosave every 15 min, restore on start; byobu's grouped sessions are not saved).
- zsh fzf bindings: `Ctrl-R` fuzzy history, `Alt-C` fuzzy cd, `Ctrl-T` file path outside byobu.
- Installer: `fzf` package, clones tmux plugins into `~/.tmux/plugins`.

### Changed
- Bottom-row clickable hints show the new keys and add a search hint.

## [1.1.0] - 2026-11-13

### Added
- `install.sh --packages` installs VS Code: winget on the Windows host under WSL, Microsoft apt repo on Linux with a desktop session.
- README: VS Code config comes from Settings Sync.

## [1.0.0] - 2026-11-13

### Added
- Initial repo: zsh (antidote, replaces Prezto), Starship prompt and status config, byobu 4-row status bar, vim (vim-plug, replaces pathogen), Windows Terminal settings merge, `install.sh` with backup-then-link.

[1.4.1]: https://github.com/spanthetree/dotfiles/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/spanthetree/dotfiles/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/spanthetree/dotfiles/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/spanthetree/dotfiles/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/spanthetree/dotfiles/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/spanthetree/dotfiles/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/spanthetree/dotfiles/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/spanthetree/dotfiles/releases/tag/v1.0.0
