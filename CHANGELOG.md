# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org/), tagged `vX.Y.Z`.

## [2.3.1] - 2026-11-15

### Fixed
- Package uninstall prompt: it never asked and always demanded `--yes` (Python can't open `/dev/tty` read-write in text mode); also affected the Windows prompt.
- Sysinternals Suite installs from the Microsoft Store (`9P7KNL5RWT25`): winget's `Microsoft.Sysinternals.Suite` fails its hash check whenever Microsoft updates the unversioned zip before the manifest.

## [2.3.0] - 2026-11-14

### Added
- Alt-D tab popup covers every session: tabs grouped by session in aligned, themed columns (boxed tab numbers, current tab highlighted), with a preview of the tab's screen or the lines around a text match.
- Alt-D actions on the selected tab: `Ctrl-T` new tab after it, `F8` rename, `Alt-M` move to another or a new session (following it if it was the session's last tab), `Ctrl-W` twice close.
- `bin/fzf-theme`: shared SynthWave '84 fzf colors for the popups; popups get rounded, themed borders.

### Changed
- Tab search text matches must contain the typed words in the line itself (not only in the tab name), and results stay in session order.

## [2.2.0] - 2026-11-14

### Added
- `settings.upgrade` in `packages.yaml` (on): each `--packages` run also does `apt-get upgrade`.
- GitHub release binaries update to their latest release on later runs (installed tag recorded per binary; only binaries in `~/.local/bin`). Existing machines re-download each once.
- `mtrr` alias: `mtr -z -b -r -w -c 10` (report with AS numbers, hostnames and IPs).

### Removed
- trippy (`trip`): its map needs GeoIP data it can't get from the free DB-IP file, and its reports have no AS column. The next `--packages` run offers to uninstall it.

## [2.1.0] - 2026-11-14

Existing machines: run `install.sh --packages` for the new tools.

### Added
- Modern CLI tools: dust, duf, gdu, yazi, broot, ouch, sd, choose, jless, fx, difftastic (`difft`), hexyl, procs, hyperfine, viddy, watchexec, entr, just, scc, gping, trippy (`trip`), doggo, bandwhich. `trip` and `bandwhich` get capabilities so they run without sudo.
- `packages.yaml` GitHub entries can be `.zip`, `.tar.xz` or a bare binary.
- Tab search (`Alt-D`) also searches pane text and scrollback while typing (exact match), jumps to the line in copy mode; `Alt-D` again closes it.
- `Ctrl-Alt-Left`/`Right` move the current tab; `Ctrl-S` saves tabs now.
- Tab bar scrolls to keep the current tab in view when tabs overflow (◀ ▶ markers); names over 24 characters are cut.
- zsh: Ctrl-Left/Right, Home/End, Ctrl-Backspace/Delete, Shift-Tab, Ctrl-X Ctrl-E (lost with Prezto).

### Changed
- `Ctrl-W` closes a tab on a second `Ctrl-W` (or `y`); any other key cancels.
- Search hint moved to the right of the tab bar.
- `VISUAL` is vim.

### Fixed
- Tabs not restored after `wsl --shutdown` when several terminals start byobu at once: `bin/restore-tabs` replaces continuum's restore and restores into the startup session instead of adding one.

## [2.0.0] - 2026-11-14

Existing machines: run `install.sh --packages --adopt` once (so removing a package from `packages.yaml` uninstalls it), then `wsl --shutdown` from Windows (mirrored networking).

### Added
- `packages.yaml`: every package for Linux and Windows in one file. Plain names for apt/winget; maps add an apt repo, a GitHub release binary, an install script, `skip_if`/`update`/`post`/`uninstall` steps, or `when: desktop|wsl`. Read by `packages.py` (Linux, and Windows under WSL) and `install.ps1` (via the `powershell-yaml` module).
- Removing a package from `packages.yaml` uninstalls it on the next run, after a y/N prompt (`--yes` skips it). Only packages the installer installed are removed (record in `~/.local/state/dotfiles/` and `%LOCALAPPDATA%\dotfiles\`); `--adopt` records what's already installed; core packages are never removed. `settings.autoremove` also clears leftover apt dependencies.
- Language tools as `tools:` under `go` (`go install`), `pyenv` (`uv tool install`) and `rbenv` (`gem install`).
- Go: latest official release in `/usr/local/go`, upgraded each run; gopls.
- Ruby: rbenv + ruby-build with Ruby 3.2, 3.4 (global) and 4.0; Ruby version in the byobu status row.
- Tools: nmap, tcpdump, tshark, termshark, iperf3, ipcalc, mtr, dig, gh, kubectx, k9s, stern, lazygit, AWS CLI v2, shellcheck, delta, direnv, btop, ncdu, tldr.
- Windows apps: Wireshark, Nmap, PowerToys, Sysinternals Suite, Everything.
- WSL2 mirrored networking (`networkingMode=mirrored` in `.wslconfig`).
- git uses delta as its pager (`git/delta.gitconfig`, included from `~/.gitconfig`); direnv hook in zsh; vim-terraform.

### Changed
- `install.sh --packages` keeps going when one package fails and lists failures at the end.
- apt repo keys are refreshed every run.
- `install.ps1` installs Git and clones the repo before reading the app list.
- Proxy references removed from the docs.

### Fixed
- `libncursesw5-dev` (virtual on Ubuntu 24.04) replaced by `libncurses-dev`.

## [1.5.0] - 2026-11-13

### Added
- `install.sh --packages` installs Python 3.11, 3.12 and 3.14 (latest patch of each) with pyenv, and sets 3.12 as global if the global is still `system`.

### Changed
- `install.sh --packages` updates an existing `~/.pyenv` (`git pull --ff-only`) so new Python versions can be installed.

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

[2.3.1]: https://github.com/spanthetree/dotfiles/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/spanthetree/dotfiles/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/spanthetree/dotfiles/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/spanthetree/dotfiles/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/spanthetree/dotfiles/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/spanthetree/dotfiles/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/spanthetree/dotfiles/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/spanthetree/dotfiles/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/spanthetree/dotfiles/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/spanthetree/dotfiles/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/spanthetree/dotfiles/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/spanthetree/dotfiles/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/spanthetree/dotfiles/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/spanthetree/dotfiles/releases/tag/v1.0.0
