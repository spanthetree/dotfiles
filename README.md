# dotfiles

zsh (antidote), Starship, Byobu/tmux, vim (vim-plug) and Windows Terminal, in a SynthWave '84 theme.

## Install

```sh
gh repo clone spanthetree/dotfiles ~/dotfiles
~/dotfiles/install.sh --packages   # first time: also installs tools (Debian/Ubuntu)
~/dotfiles/install.sh              # later: just re-link configs
```

Configs are symlinked, so editing `~/.zshrc` etc. edits this repo. Anything already in the way is moved to `~/.dotfiles-backup/<timestamp>/`, never deleted. Re-running is safe.

Update a machine: `git -C ~/dotfiles pull && ~/dotfiles/install.sh`

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
| `starship/starship.toml` | prompt: user@host, cwd, active virtualenv |
| `starship/starship-status.toml` | git/python/go/k8s/terraform, shown in byobu row 3 |
| `byobu/` | `~/.config/byobu/`: 4-row status bar, pulsing active tab, clickable F-key hints |
| `vim/vimrc` | `~/.vimrc`; plugins via vim-plug into `~/.vim/plugged` |
| `windows-terminal/settings.patch.json` | merged into WT `settings.json` under WSL (scheme + defaults only) |

Check the WT merge logic: `python3 -I windows-terminal/test_merge.py`
