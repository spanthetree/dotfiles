# dotfiles

zsh (antidote), Starship, Byobu/tmux, vim (vim-plug) and Windows Terminal, in a SynthWave '84 theme.

Current version: see [CHANGELOG.md](CHANGELOG.md) or `git -C ~/dotfiles describe --tags`.

## Install

```sh
gh repo clone spanthetree/dotfiles ~/dotfiles
~/dotfiles/install.sh --packages   # first time: also installs tools (Debian/Ubuntu)
~/dotfiles/install.sh              # later: just re-link configs
```

Configs are symlinked, so editing `~/.zshrc` etc. edits this repo. Anything already in the way is moved to `~/.dotfiles-backup/<timestamp>/`, never deleted. Re-running is safe.

Update a machine: `git -C ~/dotfiles pull && ~/dotfiles/install.sh`

### New Windows machine

From any PowerShell window:

```powershell
irm https://raw.githubusercontent.com/spanthetree/dotfiles/main/install.ps1 -OutFile $env:TEMP\dotfiles.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\dotfiles.ps1
```

It asks for admin, then:
1. Installs Windows Terminal, VS Code, Git, YASB, Claude Desktop, OpenCode Desktop, PowerToys, Sysinternals, Everything, Wireshark, Nmap and JetBrainsMono Nerd Font (winget). Wireshark/Nmap may show the Npcap setup window: click through it.
2. Clones this repo to `%USERPROFILE%\dotfiles` and points YASB at `windows\yasb` (`YASB_CONFIG_HOME`), with autostart on.
3. Asks which Debian/Ubuntu distro to install, enables WSL2 (reboots once if needed and resumes after sign-in), and installs the distro. Create your Linux user, then type `exit`.
4. Inside WSL, clones this repo to `~/dotfiles` and runs `install.sh --packages`, which also patches Windows Terminal.

App list: `windows:` in `packages.yaml`. The script installs the `powershell-yaml` module (current user) to read it.

Re-running is safe. Two clones exist: Windows (YASB config) and WSL (everything else).

## Per-machine files (never committed)

| File | For |
|---|---|
| `~/.zshrc.local` | kube contexts, machine-only aliases |
| `~/.zsh_secrets.gpg` | tokens; decrypted and sourced at shell start |
| `~/.config/byobu/disable-autolaunch` | touch it to stop byobu auto-starting |

## Layout

| Path | Linked to |
|---|---|
| `zsh/zshrc`, `zshenv`, `zprofile`, `zsh_aliases`, `zsh_plugins.txt` | `~/.zshrc` etc. |
| `starship/starship.toml` | prompt: user@host, cwd, virtualenv; on demand: duration, jobs, sudo, exit code |
| `starship/starship-status.toml` | git/python/go/k8s/terraform, shown in byobu row 3; k8s contexts matching `prod` turn red |
| `byobu/` | `~/.config/byobu/`: 4-row status bar, pulsing active tab, clickable key hints |
| `vim/vimrc` | `~/.vimrc`; plugins via vim-plug into `~/.vim/plugged` |
| `windows-terminal/settings.patch.json` | merged into WT `settings.json` under WSL (scheme + defaults only) |
| `windows/yasb/` | YASB status bar config, read in place via `YASB_CONFIG_HOME` |
| `git/delta.gitconfig` | included from `~/.gitconfig`: delta as git pager (identity stays per machine) |
| `packages.yaml` | every package: `linux:` (apt, apt repos, GitHub releases, install scripts) and `windows:` (winget ids). Edit, re-run the installer |
| `packages.py` | reads `packages.yaml` for `install.sh --packages` |
| `install.ps1` | Windows bootstrap (see above) |

The installer also clones tmux-resurrect and tmux-continuum into `~/.tmux/plugins`.

Packages: see [`packages.yaml`](packages.yaml), the one list for both systems. To add one, add a line and re-run `install.sh --packages`. To remove one, delete its line and re-run: the installer asks, then uninstalls it, but only if it installed it on that machine (recorded in `~/.local/state/dotfiles/linux.json` and `%LOCALAPPDATA%\dotfiles\windows.installed`). On a machine set up before this existed, run `install.sh --packages --adopt` once. Language tools go under their language's entry as `tools:` (go: `go install`, pyenv: `uv tool install`, rbenv: `gem install`), so they install after it and leave with it. Core packages (git, curl, zsh, python3...) are never removed; `settings.autoremove` also clears leftover apt dependencies. Highlights: network tools (nmap, tshark, mtr, bgpq4, xh/`ht`), Kubernetes (kubectl, k9s, stern, helm), terraform, ansible, Docker, AWS CLI, pyenv with Python 3.11/3.12 (global)/3.14, uv, rbenv with Ruby 3.2/3.4 (global)/4.0, Go (latest, plus gopls), and the Claude Code, Codex and OpenCode CLIs.

Under WSL, `install.sh` also sets `networkingMode=mirrored` in `%USERPROFILE%\.wslconfig` (WSL shares Windows' network interfaces, so nmap/tcpdump see the real LAN; apply with `wsl --shutdown`), and points git's pager at delta via `include.path` to `git/delta.gitconfig`.

## Keys

Byobu (browser-style; byobu's own F-keys and Alt+arrows still work):

| Key | Does |
|---|---|
| `Ctrl-T` | new tab (passes through to vim) |
| `Ctrl-W` | close tab, asks first (passes through to vim) |
| `Ctrl-PgUp` / `Ctrl-PgDn` | previous / next tab |
| `Alt-1`…`Alt-8`, `Alt-9` | jump to tab N, last tab |
| `Alt-D` | fuzzy tab search popup |
| `Ctrl-F7` | toggle logging this pane to `~/logs/` |
| `Ctrl-A Ctrl-S` / `Ctrl-A Ctrl-R` | save / restore sessions (also autosaved every 15 min, restored on start) |

zsh: `Ctrl-R` fuzzy history (fzf), `Alt-C` fuzzy cd, Up/Down history substring search. `Ctrl-W` is taken by byobu, so delete a word with `Alt-Backspace`.

## VS Code

`install.sh --packages` installs it (Windows host under WSL; Linux only with a desktop). Settings, extensions, keybindings and theme come from VS Code Settings Sync: sign in with GitHub. WSL extensions install automatically from the `remote.defaultExtensionsIfInstalledLocally` list in synced settings.

## Versioning

Semantic versions as git tags (`vMAJOR.MINOR.PATCH`), each listed in [CHANGELOG.md](CHANGELOG.md). New feature: minor. Fix: patch. Change that needs manual steps on existing machines: major.

## Checks

WT merge logic: `python3 -I windows-terminal/test_merge.py`

Windows installer helpers: `powershell -ExecutionPolicy Bypass -File windows\test_install.ps1`

## License

[MIT](LICENSE)
