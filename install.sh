#!/usr/bin/env bash
# Install dotfiles by symlinking into $HOME. Safe to re-run.
#   ./install.sh             link configs, bootstrap antidote + vim-plug, patch Windows Terminal (WSL)
#   ./install.sh --packages  also install missing tools from packages.yaml, uninstall removed ones (Debian/Ubuntu)
#     --adopt   once per existing machine: treat everything already installed from packages.yaml as managed
#     --yes     uninstall removed packages without asking
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
PACKAGES=0
PKG_FLAGS=()
for arg in "$@"; do
  case $arg in
    --packages) PACKAGES=1 ;;
    --adopt|--yes) PACKAGES=1; PKG_FLAGS+=("$arg") ;;
    -h|--help) sed -n '2,6s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Move $1 into the backup dir, keeping its path relative to $HOME. Never deletes.
backup() {
  local rel="${1#"$HOME"/}"
  mkdir -p "$BACKUP/$(dirname "$rel")"
  mv "$1" "$BACKUP/$rel"
  log "backed up ~/$rel -> $BACKUP/$rel"
}

# link <path in repo> <destination>
link() {
  local src="$DOT/$1" dest="$2"
  [[ -L $dest && $(readlink "$dest") == "$src" ]] && return 0
  if [[ -e $dest || -L $dest ]]; then backup "$dest"; fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log "linked $dest"
}

# ---------------------------------------------------------------- packages
install_packages() {
  if ! have apt-get; then
    warn "--packages supports Debian/Ubuntu only; install what you need from packages.yaml by hand"
    return 0
  fi
  local sudo=()
  [[ $EUID -ne 0 ]] && sudo=(sudo)
  # packages.py needs the system python3 + PyYAML (not pyenv's python) to read packages.yaml, and gpg for apt repo keys
  if ! /usr/bin/python3 -c 'import yaml' 2>/dev/null || ! have gpg; then
    "${sudo[@]}" apt-get update -qq
    DEBIAN_FRONTEND=noninteractive "${sudo[@]}" apt-get install -y -qq python3 python3-yaml gnupg
  fi
  /usr/bin/python3 -I "$DOT/packages.py" linux "${PKG_FLAGS[@]}"
  is_wsl && have winget.exe && /usr/bin/python3 -I "$DOT/packages.py" windows "${PKG_FLAGS[@]}"

  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    log "default shell -> zsh"
    "${sudo[@]}" chsh -s "$(command -v zsh)" "$USER"
  fi
}

# ---------------------------------------------------------------- configs
retire_old_setup() {
  # Prezto-era links that the new zsh setup doesn't use
  local f
  for f in .zlogin .zlogout .zpreztorc; do
    [[ -L $HOME/$f && $(readlink "$HOME/$f") == */.zprezto/* ]] && backup "$HOME/$f"
  done
  # Old pathogen vim repo; vim-plug manages ~/.vim/plugged now
  if [[ -d $HOME/.vim/bundle && -d $HOME/.vim/.git ]]; then backup "$HOME/.vim"; fi
  return 0
}

link_configs() {
  link zsh/zshrc            "$HOME/.zshrc"
  link zsh/zshenv           "$HOME/.zshenv"
  link zsh/zprofile         "$HOME/.zprofile"
  link zsh/zsh_aliases      "$HOME/.zsh_aliases"
  link zsh/zsh_plugins.txt  "$HOME/.zsh_plugins.txt"
  link starship/starship.toml        "$HOME/.config/starship.toml"
  link starship/starship-status.toml "$HOME/.config/starship-status.toml"
  link byobu/profile.tmux   "$HOME/.config/byobu/profile.tmux"
  link byobu/color.tmux     "$HOME/.config/byobu/color.tmux"
  link byobu/backend        "$HOME/.config/byobu/backend"
  link byobu/bin            "$HOME/.config/byobu/bin"
  link vim/vimrc            "$HOME/.vimrc"
}

bootstrap_plugins() {
  local p
  for p in tmux-resurrect tmux-continuum; do
    if [[ ! -d $HOME/.tmux/plugins/$p ]] && have git; then
      log "tmux plugin $p"
      git clone -q --depth=1 "https://github.com/tmux-plugins/$p" "$HOME/.tmux/plugins/$p"
    fi
  done
  if [[ ! -d $HOME/.antidote ]] && have git; then
    log "antidote"
    git clone -q --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
  if have zsh && [[ -r $HOME/.antidote/antidote.zsh ]]; then
    log "zsh plugins"
    zsh -c 'source ~/.antidote/antidote.zsh && antidote bundle <~/.zsh_plugins.txt >~/.zsh_plugins.zsh'
  fi
  if have vim && have curl; then
    if [[ ! -f $HOME/.vim/autoload/plug.vim ]]; then
      log "vim-plug"
      curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    log "vim plugins"
    vim -Nu "$HOME/.vimrc" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' </dev/null >/dev/null 2>&1 || true
  fi
}

patch_windows_terminal() {
  is_wsl || return 0
  have cmd.exe || return 0
  local appdata settings
  appdata=$(cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')
  settings="$(wslpath "$appdata")/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ ! -f $settings ]]; then
    warn "Windows Terminal settings.json not found (open Windows Terminal once, then re-run)"
    return 0
  fi
  log "Windows Terminal: merging scheme and defaults"
  mkdir -p "$BACKUP"
  cp "$settings" "$BACKUP/windows-terminal-settings.json"
  python3 -I "$DOT/windows-terminal/merge.py" "$settings" "$DOT/windows-terminal/settings.patch.json"
}

# WSL2 mirrored networking: WSL shares Windows' interfaces, so nmap/tcpdump see the real LAN.
# Takes effect after `wsl --shutdown`.
configure_wsl() {
  is_wsl && have cmd.exe || return 0
  local f; f="$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  grep -qiE '^\s*networkingMode\s*=\s*mirrored' "$f" 2>/dev/null && return 0
  [[ -f $f ]] && { mkdir -p "$BACKUP"; cp "$f" "$BACKUP/wslconfig"; }
  if grep -qiE '^\s*networkingMode' "$f" 2>/dev/null; then
    sed -i -E 's/^\s*networkingMode\s*=.*/networkingMode=mirrored/I' "$f"
  elif grep -q '^\[wsl2\]' "$f" 2>/dev/null; then
    sed -i '/^\[wsl2\]/a networkingMode=mirrored' "$f"
  else
    printf '[wsl2]\nnetworkingMode=mirrored\n' >> "$f"
  fi
  warn "WSL networking set to mirrored in $f; run 'wsl --shutdown' from Windows to apply"
}

# git: delta as pager via an include, so ~/.gitconfig (identity, credentials) stays per machine
configure_git() {
  have delta && have git || return 0
  git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/git/delta.gitconfig" && return 0
  git config --global --add include.path "$DOT/git/delta.gitconfig"
  log "git: delta pager"
}

[[ $PACKAGES -eq 1 ]] && install_packages
retire_old_setup
link_configs
bootstrap_plugins
patch_windows_terminal
configure_wsl
configure_git
[[ -d $BACKUP ]] && log "backups in $BACKUP"
log "done. Start a new terminal (or: exec zsh -l)"
