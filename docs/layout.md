# Layout

Everything for Linux/WSL is in `linux/`, everything for Windows in `windows/`. The root holds the entry point, the shared package list and the docs.

| Path | Linked to / does |
|---|---|
| `install.cmd` | the installer for both systems: Linux/WSL runs `linux/install.sh`, Windows runs `windows\install.ps1` ([install](install.md)) |
| `packages.yaml` | every package, for both systems ([packages](packages.md)) |
| `linux/zsh/zshrc`, `zshenv`, `zprofile`, `zsh_aliases`, `zsh_plugins.txt` | `~/.zshrc` etc.; plugins via antidote |
| `linux/starship/starship.toml` | prompt: user@host, cwd, virtualenv; on demand: duration, jobs, sudo, exit code |
| `linux/starship/starship-status.toml` | git/python/go/k8s/terraform, shown in byobu row 3; k8s contexts matching `prod` turn red |
| `linux/byobu/` | `~/.config/byobu/`: 4-row status bar, pulsing active tab, clickable key hints |
| `linux/byobu/bin/` | status scripts, `tab-search` (Alt-D popup), `tab-move`, `restore-tabs`, shared `fzf-theme` |
| `linux/vim/vimrc` | `~/.vimrc`; plugins via vim-plug into `~/.vim/plugged` |
| `windows/terminal/` | `settings.patch.json` merged into Windows Terminal's `settings.json` from WSL (scheme + defaults only), by `merge.py` |
| `windows/yasb/` | YASB status bar config, read in place via `YASB_CONFIG_HOME` |
| `linux/git/delta.gitconfig` | included from `~/.gitconfig`: delta as git pager (identity stays per machine) |
| `linux/install.sh`, `linux/install-fx.sh`, `linux/packages.py` | Linux/WSL installer, its look, and the package installer (also installs the Windows apps from WSL) |
| `windows/install.ps1` | Windows bootstrap: apps, YASB, WSL, then the Linux installer inside WSL |
| `docs/` | these docs, and `logo.svg` (the README logo) |
| `CLAUDE.md` | notes for AI agents: rules, release steps, testing, gotchas |

The installer also clones tmux-resurrect and tmux-continuum into `~/.tmux/plugins`. Tabs autosave every 15 minutes and are restored when byobu starts (`bin/restore-tabs`).
