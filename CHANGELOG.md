# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org/), tagged `vX.Y.Z`.

## [5.1.0] - 2026-11-25

### Added
- `tun`: SSH tunnels that rebuild themselves (autossh): `tun bastion -D 1080`, `tun db-jump -L 5432:db.internal:5432`, `tun lab -R 8080:localhost:3000`. No shell; reconnects after a dropped link; stops if the first connection fails (no retry loop on a wrong password), or at once if the port is taken. Completes host names like ssh.
- Shared SSH defaults, included at the end of `~/.ssh/config` so your own settings win: keepalives for every host (a dead connection ends within ~90s instead of freezing), and connection reuse for hosts you tag with `Tag mux` (OpenSSH 9.4+). Reuse is opt-in because network gear often allows one session per connection and a kept-open connection holds a vty line. The files are copied to `~/.ssh` with mode 600, since ssh refuses group-writable config files. `--uninstall` removes them; `--check` checks them.

## [5.0.1] - 2026-11-25

### Fixed
- Native Windows installs (`install.cmd` on Windows) failed reading `packages.yaml` since 4.3.0: powershell-yaml misreads an inline `{...}` entry whose quoted value has braces in it (`${XDG_STATE_HOME:-...}`). Those entries are now written one key per line (same values), and `tests/lint.sh` rejects inline entries. Installs from WSL were not affected (they read the file with Python).
- CI's PowerShell syntax check passed its files to `pwsh -Command`, which read them as code.

## [5.0.0] - 2026-11-25

Upgrading from 4.x: `git -C ~/dotfiles pull && ~/dotfiles/install.cmd`, then open a new shell. Python, Ruby and Go now come from mise: zsh no longer loads pyenv or rbenv, and once mise's versions are in, the installer asks whether to remove `~/.pyenv`, `~/.rbenv` and `/usr/local/go`. Move what you built on them by hand first: virtualenvs, gems in rbenv's Ruby, older Pythons (`mise use -g python@<version>`). The pre-commit privacy check turns on with that run; add your own patterns to `~/.config/dotfiles/private-patterns`.

### Added
- CI on every push and pull request (`.github/workflows/checks.yml`): lint (syntax, shellcheck, `packages.yaml`, PowerShell parsing), gitleaks over the whole history, the installer scenarios in fresh Ubuntu 24.04 and 26.04 containers, and the Windows installer's tests on a Windows runner. The same runs locally: `tests/lint.sh` and `tests/run.sh` (scenarios in `tests/scenarios`).
- A privacy check before each commit (`.githooks/pre-commit`, turned on by the installer for this clone): stops a commit that adds a secret (gitleaks), an email address, or a line matching your own patterns in `~/.config/dotfiles/private-patterns`, which stays on your machine.
- `install.cmd --check`: changes nothing, lists what differs from the repo (links, packages a run would install or uninstall, COSMIC settings, the commit hook), exits 1 if anything does.
- kind (local Kubernetes clusters in Docker), autossh (self-reconnecting SSH tunnels), gitleaks.
- Beeper, on a Linux desktop and on Windows (not in WSL). Before installing it, the installer checks the machine for software that could read your chats: Beeper keeps them decrypted in a local database and shows them on screen. It looks for endpoint security (CrowdStrike, SentinelOne, Defender for Endpoint and others), data loss prevention, file-query agents (osquery, Tanium, Velociraptor) and screen monitoring (Teramind, ActivTrak, Hubstaff...). If any are found, it names them and asks first (default no), and remembers the answer until the findings change. It's a generic `private:` key in `packages.yaml`, checked by `linux/monitoring-check` and `windows/monitoring-check.ps1`. On Linux the AppImage is unpacked into `~/.local/opt/beeper` and updated by the installer, keeping Chromium's sandbox on (an AppArmor profile allows the user namespaces it needs on Ubuntu 24.04+; Beeper's own launcher turns the sandbox off).
- rustup with the stable Rust toolchain (rustc, cargo, clippy, rustfmt, rust-analyzer), updated on each run. It was on the owner's machine but set up by hand, so new machines didn't get it.

### Changed
- `packages.yaml` is grouped by what each tool is for (base, shell, files, data, languages, dev, containers, cloud, network, notes and AI, desktop, Hyprland, COSMIC; Windows likewise), under banner comments, and every entry has a comment saying what it's for. The entries themselves are unchanged.
- Python and Ruby versions come from mise instead of pyenv and rbenv: Python 3.11, 3.12 (global) and 3.14, Ruby 3.2, 3.4 (global) and 4.0, prebuilt, so they install in seconds instead of compiling. The newest patch release of each is added on every run, and a global version you set yourself (`mise use -g`) is kept. `.python-version` and `.ruby-version` files still pick the version per project (`MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS` in `zshenv`). The byobu status row finds versions through mise's shims. The uv tools (ptpython, bpython, httpstat) now sit under the `uv` entry; ruby `tools:` go into mise's global Ruby.
- Go comes from mise too: the latest release, under `~/.local/share/mise`, with no sudo. `GOPATH` stays `~/go`, so `go install` tools (gopls) stay where they were. On an existing machine the next run offers to uninstall the old `/usr/local/go`. `zshenv` no longer sets `GOROOT`, and puts mise's shims last on `PATH` so scripts and editors find mise's Go, Python and Ruby.
- carapace completes only commands zsh has no completion for. zsh's own (git, ssh, systemctl, apt, docker...) are richer, so they're kept. For commands neither knows, carapace falls back to zsh's, fish's or bash's (`CARAPACE_BRIDGES`).
- zsh-autosuggestions suggests from history first, then from completion (it was completion only).

### Fixed
- `--no-fx` didn't reach the package step, which kept its spinners.

### Removed
- pyenv and rbenv. On an existing machine, once mise's Python and Ruby are installed, a run asks (separately from other removals) whether to uninstall them, and the old `/usr/local/go`: that deletes their Pythons, Rubies, virtualenvs and gems, so reinstall any you still need with mise (`mise use -g python@3.12`, `gem install`). No keeps them for good, no longer managed by the installer; zsh no longer loads them either way. uv tools built on a pyenv Python that's gone are reinstalled.

## [4.4.0] - 2026-11-25

### Added
- trippy (`trip`), a traceroute + ping TUI, from its GitHub release with `cap_net_raw` so it runs without sudo. Config in `linux/trippy/trippy.toml` (AS names, IP and hostname per hop, SynthWave '84 colours). Its world map and hop locations use MaxMind's free GeoLite2 City database: the installer asks once for a MaxMind account ID and license key (Enter skips) and keeps the database current with geoipupdate on each run.
- SuzieQ (`suzieq-cli`, `suzieq-gui`, `sq-poller`): polls network devices over SSH into a store you can query. Installed with uv on Python 3.10-3.11, with uvloop (SuzieQ needs it but doesn't declare it). The installer writes `~/.suzieq/suzieq-cfg.yml` from `linux/suzieq/suzieq-cfg.yml` with your home directory and timezone filled in; a config you wrote yourself is left alone. Devices to poll go in `~/.suzieq/inventory.yml`, per machine. The `sq-poller` function in `zshrc` makes the poller's workers use SuzieQ's own Python instead of pyenv's.
- rustnet, a network monitor TUI showing connections per process, from its PPA (domcyrus/rustnet).
- sshs, a TUI for picking a host from `~/.ssh/config`, from its GitHub release. The `sshs` alias sets SynthWave '84 pink (sshs takes only Tailwind palette names).
- termscp, a TUI file transfer client (SFTP, SCP, FTP, S3, SMB, WebDAV), from its GitHub release, with a SynthWave '84 theme in `linux/termscp/theme.toml`.
- tldr pages set up by the installer: tealdeer now comes from its GitHub release (Ubuntu 24.04's apt build can't download pages any more), the installer fetches and refreshes the pages each run, and `linux/tealdeer/config.toml` turns on weekly self-updates and SynthWave '84 colours.
- Shell: carapace completions, navi cheatsheets on `Ctrl-G` (with denisidoro/cheats), mise (activated after pyenv/rbenv/nvm), fzf from its GitHub release with `fzf --zsh` key bindings, tmux-fingers on `F12 F`, `kitten icat` (`icat` alias; byobu now allows passthrough).
- Data and logs: jaq, gron, jc, lnav, rare, VisiData.
- Dev: d2, sops + age, step, grpcurl, websocat, usql, kcat, httpstat.
- Kubernetes and cloud: krew with neat, tree, view-secret, node-shell, df-pv and who-can; kubeshark; helm-diff; helmfile; tflint; terraform-docs; infracost; steampipe; granted (`assume` alias).
- Network: asn, globalping, monocle, gnmic, lldpd, RustScan, nmap-formatter, arp-scan, fping, hping3, scamper, grepcidr, mapcidr, ngrep, tcpflow, conntrack, ethtool, pwru, bpftrace, BCC tools, oha; TTP with ntc-templates (the `ntc` function parses show-command output to JSON).
- containerlab, from its release `.deb`; you're added to `clab_admins` so it runs without sudo (next login). `netshoot` and `knetshoot` functions open nicolaka/netshoot in a container's or pod's network namespace.
- Joplin for notes: the terminal app (`joplin`, with its own Node LTS in `~/.local/share/joplin-cli`), the desktop app on a Linux desktop (Joplin's installer, `~/.joplin`) and on Windows (winget). Sync is set per machine in each app.
- Aliases for drop-in replacements: `top`/`htop` → btop, `watch` → viddy, `ncdu` → gdu, `cloc` → scc, `http`/`https` → xh, `tree` → `eza --tree`.
- `packages.yaml`: `extra:` installs more binaries from the same GitHub release archive; krew entries take `tools:` (kubectl plugins); an entry's apt repo is removed along with it.
- COSMIC: the input method in the panel as `EN` / `あ`, like the Hyprland panel's (click switches, right click opens fcitx5's settings). This repo's own small applet (`linux/cosmic/input-applet`), built with cargo by `packages.yaml`: COSMIC's Input Sources applet shows only the keyboard layout, and fcitx5's tray icon only shows among every other tray icon.
- COSMIC: the panel and dock settings: see-through and small, with the applet layout in `linux/cosmic/panel` (status area, input sources, accessibility and tiling applets out; notifications next to the clock).
- Linux desktops: the DepartureMono (retro-futuristic pixel) and Terminess (Terminus) Nerd Fonts, from the Nerd Fonts release, next to FantasqueSansM and JetBrainsMono.

### Changed
- kitty: Departure Mono Nerd Font at 16.5 pt (22 px, where the pixel font is sharp), instead of FantasqueSansM at 14.
- The Hyprland layer (hyprbars, hyprfocus, Hyprspace, hyprshell, wayle, kanshi, wf-recorder; `when: in-hyprland` in `packages.yaml`) is installed and updated only on a run from inside Hyprland, or where `--hyprland` was chosen. From COSMIC or GNOME it's skipped quietly (and kept): no more hyprbars notice or hyprshell update there.
- helm is always this installer's own, in `~/.local/bin`: an older helm installed some other way can't load the current helm-diff plugin. Remove the other one (e.g. `/usr/local/bin/helm`), which comes first on the PATH.
- terraform comes from tenv (`terraform`, `tofu`, `terragrunt` proxies; the version follows each project), not HashiCorp's apt repo. The next run offers to uninstall the apt terraform.

### Removed
- COSMIC: the Hyprland setup's wallpaper as COSMIC's background. skwd-wall (`Super-W`) sets the wallpaper; COSMIC's own background goes back to what it was before (unless changed in Settings since). A setting dropped from `COSMIC_KEYS` now always goes back this way.
- Duplicates of other tools: httpie (xh), ncdu (gdu), cloc (scc), entr (watchexec), bandwhich (rustnet), jless (fx), tcptraceroute (`trip -P tcp`, `mtr --tcp`). The next run offers to uninstall them.

### Fixed
- A desktop's settings and links were removed whenever its programs were missing during a run (e.g. after apt removed them), as if `--no-cosmic` / `--no-hyprland` had been given: COSMIC's shortcuts, panel and theme were reset, and Hyprland's drop-ins unlinked (so its services crashed in COSMIC). Now only `--no-cosmic`, `--no-hyprland` or `--uninstall` remove them; otherwise the installer warns and leaves them.
- Uninstalling an apt package dropped from `packages.yaml` could remove the whole desktop: `apt-get remove -y` takes every package that depends on it, and the old `--adopt` and every install run claimed libraries already there as dependencies (they were passed to `apt-get install`, which marks them as installed by hand). Now packages already installed aren't passed to apt; only packages apt has as installed by hand count as this repo's; a package something else needs is kept as a dependency instead of removed; each removal is simulated and refused if it would take more, or anything essential or of the desktop; and the system-wide `apt-get autoremove` is gone (only what the removal itself left unneeded goes).
- An entry's own apt steps (build tools for hyprbars, wayle, hyprshell, the COSMIC applets; skwd-wall's and containerlab's packages) used `apt-get install` / `apt-get remove` directly, with the same risk. They now go through `linux/apt-deps`: it installs only what's missing and records it, and removes only what it recorded and apt can remove without taking anything else. Uninstalling containerlab also takes you out of `clab_admins`.
- `Alt-Tab` under COSMIC flipped windows at once, instead of showing the switcher, from apps with Japanese input on (VS Code, Claude Desktop and other Electron apps). fcitx5 let go of `Alt` as the app lost focus; the installer now sets its `PersistentVirtualKeyboard` (`~/.config/fcitx5/conf/waylandim.conf`), which stops that. Restart fcitx5 or log in again.
- kitty has Japanese input again: it was turned off as a workaround for the same `Alt-Tab` problem.
- An apt repo added another way too (e.g. with `add-apt-repository`) got a second, conflicting source from the installer ("Conflicting values set for option Signed-By"), and apt stopped working. The installer now uses the existing one, and removes its own copy from an earlier run.

## [4.3.0] - 2026-11-24

### Added
- `install.cmd --hyprland` (Ubuntu 26.04+) installs the Hyprland desktop setup this repo builds on: LinuxBeginnings/Ubuntu-Hyprland and its config Hyprland-Dots, both pinned, with the answers in `linux/hypr/preset.sh`. `--no-hyprland` drops it again with its own uninstaller (keeping kitty, btop and slurp). On a machine that already has it: `--hyprland --adopt` once. The hyprpm plugins build on the next installer run from inside Hyprland.
- Hyprland: Hyprspace (hyprpm plugin) is the workspace overview on tap-`Super` and `Super-A`: click a workspace to go there, drag windows between workspaces. The desktop setup's Quickshell overview is no longer used, and this installer's earlier edit to it (one row of 5) is undone.
- Hyprland: the hyprfocus plugin (from the same repo as hyprbars) flashes the window that gets keyboard focus.
- Hyprland: wayle, a panel (bar, notifications, OSD) to try in place of waybar + swaync. `~/.config/hypr/dotfiles-panel.sh wayle` switches to it, `... waybar` back; the choice holds across logins. Built with cargo from its latest release; config in `linux/wayle/config.toml` (SynthWave '84 palette), its menu button the distro logo in a SynthWave gradient. With it, the volume and brightness keys use wayle's indicator instead of a notification per press, and its audio modules follow headphones being plugged in or out.
- Hyprland: `Ctrl-Alt-Shift-R` starts and stops screen recording of the focused monitor, as in GNOME (`Ctrl-Alt-Shift-A`: an area), into `~/Videos/Screencasts`. `linux/desktop/record.sh`, with wf-recorder and slurp (`packages.yaml`).
- Hyprland: kanshi, monitor layouts that switch when screens are plugged in or out. Its profiles are per machine (`~/.config/kanshi/config`, untracked); without that file it isn't started.
- Hyprland: wallust colour scheme SynthWave-84 (`linux/wallust`), in the desktop setup's theme menu (`Super-T`); it stays through wallpaper changes.
- COSMIC as an opt-in second desktop: `install.cmd --cosmic` (`--no-cosmic` removes it, PPA included). From the community PPA hepp3n/cosmic-epoch, set up like the Hyprland one: its keys (`linux/cosmic/shortcuts.ron`: tap `Super` for the overview, `Super-Space` launcher, `Super-Return` kitty, `Super-Tab` and `Ctrl-Alt-Left/Right` for workspaces, and the rest in `docs/hotkeys.md`), tiling on for every workspace, workspaces side by side, and the SynthWave '84 theme with frosted glass, imported by the installer. Its settings are copied, not linked (COSMIC Settings replaces links); ones changed in Settings are left alone.
- COSMIC: Japanese input (fcitx5 + Mozc, `Ctrl-Space`) as under Hyprland; `Alt-Tab` with live window previews (pivot, built with cargo at a pinned commit; `Ctrl-Alt-Tab` is COSMIC's own); system monitor (sysmon; right click opens btop) and keep-awake (Caffeine) applets in the panel; the Hyprland setup's wallpaper; `Ctrl-Alt-Shift-R` / `Ctrl-Alt-Shift-A` screen recording (wl-screenrec).
- COSMIC: `Super-W` opens skwd-wall, a wallpaper picker that searches Wallhaven and applies what you pick (from its release's .debs, pinned; beta). Its wallpaper service starts only in COSMIC sessions.
- COSMIC: Bluetooth is COSMIC's own panel applet; blueman's tray icon isn't started there (`linux/cosmic/blueman.desktop`).
- `packages.yaml`: `when: hyprland` and `when: cosmic` entries install only on machines that chose that desktop.
- Windows: a wallpaper picker (`windows/wallpapers.ps1`, `Ctrl-Alt-W` or "Wallpapers" in the Start menu): searches Wallhaven (safe-for-work, at least the screen's resolution, optional purple filter), and sets the thumbnail you click as the wallpaper. Downloads go to `Pictures\Wallpapers`. `--uninstall` removes the shortcut and keeps the downloads.
- byobu: `Ctrl-Shift-N` opens a new session (a new group of tabs) in the same folder, from Windows Terminal and kitty (sent as `ESC[110;6u`, like `Ctrl-Shift-T`).
- kitty: frosted glass behind its see-through background (`background_blur`) where the compositor does it (COSMIC; Hyprland blurs on its own).
- Spotify's official app on desktops, from its snap (`packages.yaml`).

### Changed
- byobu: closing the last tab of a session moves the window to another session instead of closing the terminal (`detach-on-destroy off`).
- kitty: no input method (`wayland_enable_ime no`): fcitx5 released `Alt` on its way out of kitty, so `Alt-Tab` from kitty flipped windows instead of showing the switcher. No Japanese typing in kitty; every other app keeps it.
- Hyprland: `~/.local/bin` is on the PATH of everything Hyprland starts (a session from the login screen didn't have it), so tools installed there by `packages.yaml` work from bars, menus and keys.
- waybar's workspace buttons show the workspaces that exist (was always 5), as Hyprspace adds them.
- hyprshell (Alt-Tab, Super-Space) is smaller (`scale = 3`, about 210 x 120 per window on a 1440p screen) and themed by `linux/hyprshell/styles.css`. Super-Space opens mid-screen, with a narrower launcher.

### Fixed
- Hyprland's hypridle, hyprpaper and swaync no longer start in other desktops (Ubuntu enables their services for every session; hypridle ran hyprlock on idle there). A systemd drop-in (`linux/hypr/hyprland-only.conf`) limits them to Hyprland.
- hyprbars is only installed and updated from a run inside Hyprland. From another desktop hyprpm can't tell which plugin commit matches this Hyprland: it built the latest, which can fail to build, and its update failed outright. The installer says when the plugins are still to come.

### Removed
- Terminator: its `packages.yaml` entry and config. kitty is the Linux terminal. The installer removes the old `~/.config/terminator/config` link (putting back any config it had replaced) and offers to uninstall Terminator where it installed it.

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

[5.1.0]: https://github.com/spanthetree/dotfiles/compare/v5.0.1...v5.1.0
[5.0.1]: https://github.com/spanthetree/dotfiles/compare/v5.0.0...v5.0.1
[5.0.0]: https://github.com/spanthetree/dotfiles/compare/v4.4.0...v5.0.0
[4.4.0]: https://github.com/spanthetree/dotfiles/compare/v4.3.0...v4.4.0
[4.3.0]: https://github.com/spanthetree/dotfiles/compare/v4.2.0...v4.3.0
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
