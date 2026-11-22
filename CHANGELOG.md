# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org/), tagged `vX.Y.Z`.

## [4.2.0] - 2026-11-22

### Added
- Hyprland (when installed, e.g. by a Hyprland desktop setup on Ubuntu 26.04 with Hyprland 0.55+ from ppa:cppiber/hyprland): `linux/hypr/dotfiles.lua`, loaded from the end of the desktop setup's `UserConfigs/user_keybinds.lua`, adds GNOME habits on top of tiling. `Super-Space` launcher, tap `Super` for the overview, GNOME-style `Alt-Tab`, `Super-Tab` and `Ctrl-Alt-Left/Right` for workspaces, `Alt-F4`, click to focus, minimize and restore (`Super-Shift-U` / `Super-U`, apps' own minimize buttons, a waybar count), and workspace 10 floating. It also starts the dock at login. `linux/hypr/windows.sh` does the window switching and minimizing. Keys in `docs/hotkeys.md`.
- hyprbars title bars (drag, maximize, minimize, close), built with hyprpm. The update step rebuilds them when the compiler changed (e.g. after an Ubuntu upgrade, when an old build crashes Hyprland) and reinstalls their build packages if an upgrade removed them.
- hyprshell (Ubuntu 26.04 on: GTK 4.18+, Hyprland 0.57+): `Alt-Tab` switcher and `Super-Space` overview with launcher, built with cargo; config in `linux/hyprshell/config.toml`.
- Japanese input: fcitx5 + Mozc under Hyprland, and ibus + Mozc on Ubuntu's GNOME with the input-source switch moved to `Ctrl-Space` (`--uninstall` puts the old GNOME settings back). The same key in both.
- kitty is installed on Linux desktops, with `linux/kitty/theme.conf`: SynthWave '84 colours as in Windows Terminal and Terminator, FantasqueSansM Nerd Font Mono 14 (also installed), 0.9 opacity, opening at 134 × 43 cells. It is included from both kitty configs kitty reads, so GNOME and Hyprland look the same.
- VS Code under Hyprland: `"password-store": "gnome-libsecret"` in `~/.vscode/argv.json`, so it finds the keyring.
- ptpython and bpython (pyenv tools), for the `ptpy` and `bpy` aliases.
- `packages.yaml`: `interactive: true` runs a step in the terminal, without the spinner, so a sudo prompt it can't avoid is seen.

### Changed
- Byobu: `Ctrl-Alt-PgUp` / `Ctrl-Alt-PgDn` move the current tab (was `Ctrl-Alt-Left/Right`, which GNOME and Hyprland use to switch workspaces).
- The installer asks for the sudo password once per run, even when a step (hyprpm) drops sudo's cached password.
- `dkc` runs `docker compose` (Compose v2, which `packages.yaml` installs) instead of `docker-compose`.
- kitty: the include line is now `include ~/.config/kitty/dotfiles.conf` (re-running the installer replaces the old one).

### Fixed
- Terminator 2.1.5 (Ubuntu 26.04): the cursor colour and hidden size text use its new option names too.
- `~/.zprofile` mentions `/etc/profile`, so the Hyprland desktop setup no longer appends `source /etc/profile` (which ran byobu's launcher a second time).
- Font uninstalls no longer fail when fontconfig was removed first.
- The desktop setup's waybar opens its wallpaper menu at a path it doesn't ship: the installer links it, so the clicks work.

## [4.1.0] - 2026-11-21

Replaces 3.3.0, 4.0.0 and 4.0.1, which were withdrawn.

### Changed
- **Breaking:** `install.cmd` installs packages by default; `--no-packages` skips them. `--packages` is still accepted and does nothing.
- Byobu: the prefix is `F12` (byobu's emacs mode), so `Ctrl-A` goes to the shell (start of line). Set in the new `linux/byobu/keybindings.tmux`.
- Byobu: `Ctrl-Shift-T` opens a new tab (was `Ctrl-T`); `F2` renames the tab and `F8` opens one (swapped from byobu's defaults). The `Alt-D` popup follows: `F8` new tab, `F2` rename.
- Windows Terminal: `Ctrl-T` opens a new tab, and `Ctrl-Shift-T` is sent through to byobu (as `ESC[116;6u`). `merge.py` now merges `actions` (by id) and `keybindings` (by keys).

### Added
- Terminator (Linux desktops): installed, with a SynthWave '84 config (`linux/terminator/config`) matching Windows Terminal. It opens login shells, so byobu auto-starts.
- kitty (when installed, e.g. by a Hyprland desktop setup): `linux/kitty/dotfiles.conf` is linked and included at the end of `~/.config/kitty/kitty.conf`. It opens login shells (byobu auto-starts), sets `TERM=xterm-256color`, turns off kitty's own shortcuts except copy/paste, and sends `Ctrl-Shift-T` to byobu. Without kitty the step is skipped. `--uninstall` removes the link and the include line.
- JetBrainsMono Nerd Font on Linux desktops (`~/.local/share/fonts`), for Terminator and starship's icons.

### Fixed
- Ctrl-C during the installer: a running step stops too (it used to keep going in the background), the packages step finishes an interrupted dpkg (`dpkg --configure -a`) on the next run, and what was installed before the Ctrl-C is still recorded, so `--uninstall` removes it.

## [3.2.0] - 2026-11-15

### Added
- README Tour: a recording of byobu (tabs, the `Alt-D` popup searching every tab's text), screenshots of the prompt, tabs and `Alt-D`, and a recording of the installer, in `docs/media/` (made in a demo container).

### Fixed
- The installer no longer fails where `$USER` isn't set (containers, cron, some SSH sessions): it uses `id -un`.

## [3.1.3] - 2026-11-15

### Fixed
- README logo renamed to `docs/logo-v2.svg`, so browsers fetch the transparent version instead of a cached one.

## [3.1.2] - 2026-11-15

### Changed
- README logo has a transparent background; its text follows the viewer's light/dark setting.

## [3.1.1] - 2026-11-15

### Changed
- README opens with a centered logo (`docs/logo.svg`): block-letter "dotfiles" in the SynthWave '84 gradient with the description, drawn as shapes so it renders the same in every browser.

## [3.1.0] - 2026-11-15

### Added
- `install.cmd --uninstall --remove-wsl` (Windows): after the normal uninstall, deletes each WSL distro that has `~/dotfiles`, with all its files (asks per distro unless `--yes`), then uninstalls WSL and turns off its Windows feature if no other distro is left. Virtual Machine Platform stays on. Without the switch, WSL and its distros stay; only what the installer added inside them is removed.

## [3.0.0] - 2026-11-15

### Changed
- **Layout:** Linux/WSL files moved to `linux/` (byobu, git, starship, vim, zsh, `install.sh`, `packages.py`), Windows files to `windows/` (`install.ps1`, `terminal/`, `yasb/`). **Existing machines: run `./install.cmd` once after pulling** to re-point the links (old ones are replaced, not backed up) and git's delta include.
- **One installer:** `install.cmd` in the root is a batch file and a shell script in one. Linux/WSL: `./install.cmd`. Windows: `install.cmd`. The bootstrap one-liner moved to `windows/install.ps1`.
- README split into `docs/`: install, hotkeys, software, packages, layout, FAQ, development.

### Added
- `install.cmd --uninstall` (`--yes` to skip questions): uninstalls the packages and apt repos it installed, removes links and plugins, restores the originals from the oldest backup, and undoes the git, Windows Terminal, `.wslconfig` and YASB changes. On Windows it also runs inside each WSL distro with the repo, then cleans up the Windows side.
- YASB from WSL: config in `%USERPROFILE%\.config\yasb`, autostart on, restart on changes (skipped when a Windows clone manages it).
- `docs/hotkeys.md`: keys this repo defines first, then each app's defaults, and the keys byobu takes from apps.
- `docs/software.md`: everything installed, with links. `docs/faq.md`.
- `CLAUDE.md`: rules, release steps, testing and gotchas for AI agents. Contributing policy in the README.

### Fixed
- Plain mode (`--no-fx`) steps no longer read the terminal (vim plugin install could wait on it).

## [2.4.0] - 2026-11-15

### Added
- Installer look: gradient title and section headers; a spinner with elapsed time on each quiet step (apt, GitHub downloads, scripts, winget, git clones, plugins), ending in `✓`/`✗`. A failed step shows its last 20 lines. Check loops show a counter.
- `install.sh --no-fx` (or `NO_FX=1`): plain output with each step's full output; also the default when output isn't a terminal.

### Changed
- `install.sh --packages` asks for the sudo password once at the start and keeps it fresh during the run.

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

[4.2.0]: https://github.com/spanthetree/dotfiles/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/spanthetree/dotfiles/compare/v3.2.0...v4.1.0
[3.2.0]: https://github.com/spanthetree/dotfiles/compare/v3.1.3...v3.2.0
[3.1.3]: https://github.com/spanthetree/dotfiles/compare/v3.1.2...v3.1.3
[3.1.2]: https://github.com/spanthetree/dotfiles/compare/v3.1.1...v3.1.2
[3.1.1]: https://github.com/spanthetree/dotfiles/compare/v3.1.0...v3.1.1
[3.1.0]: https://github.com/spanthetree/dotfiles/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/spanthetree/dotfiles/compare/v2.4.0...v3.0.0
[2.4.0]: https://github.com/spanthetree/dotfiles/compare/v2.3.1...v2.4.0
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
