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
1. Installs Windows Terminal, VS Code, Git, YASB, Claude Desktop, OpenCode Desktop and JetBrainsMono Nerd Font (winget).
2. Clones this repo to `%USERPROFILE%\dotfiles` and points YASB at `windows\yasb` (`YASB_CONFIG_HOME`), with autostart on.
3. Asks which Debian/Ubuntu distro to install, enables WSL2 (reboots once if needed and resumes after sign-in), and installs the distro. Create your Linux user, then type `exit`.
4. Inside WSL, clones this repo to `~/dotfiles` and runs `install.sh --packages`, which also patches Windows Terminal.

Re-running is safe. Two clones exist: Windows (YASB config) and WSL (everything else).

## Per-machine files (never committed)

| File | For |
|---|---|
| `~/.zshrc.local` | work proxy, kube contexts, machine-only aliases |
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
| `install.ps1` | Windows bootstrap (see above) |

The installer also clones tmux-resurrect and tmux-continuum into `~/.tmux/plugins`.

`install.sh --packages` tools (Debian/Ubuntu):
- Shell/dev: ripgrep, fd, fzf, jq, yq, cloc, zoxide, eza, bat, xclip
- HTTP/network: httpie, xh (also `ht`), tcptraceroute, whois, bgpq4, socat
- Infra: Docker + compose v2 + buildx, kubectl, helm, terraform, ansible
- Python: pyenv, uv, virtualenvwrapper
- AI CLIs: Claude Code, Codex, OpenCode (desktop apps go on Windows under WSL)

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
