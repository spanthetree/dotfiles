#!/usr/bin/env bash
# Linux/WSL installer (run it through ../install.cmd): symlinks configs into $HOME. Safe to re-run.
#   ./install.cmd             link configs, bootstrap antidote + vim-plug, patch Windows Terminal (WSL)
#   ./install.cmd --packages  also install missing tools from packages.yaml, uninstall removed ones (Debian/Ubuntu)
#     --adopt   once per existing machine: treat everything already installed from packages.yaml as managed
#     --yes     uninstall removed packages without asking
#   ./install.cmd --uninstall remove it all: links, plugins, settings, packages it installed (asks); restores backups
#   ./install.cmd --no-fx     plain output, no spinners (also off when output isn't a terminal, or NO_FX=1)
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # the repo
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
PACKAGES=0
UNINSTALL=0
PKG_FLAGS=()
for arg in "$@"; do
  case $arg in
    --packages) PACKAGES=1 ;;
    --adopt|--yes) PACKAGES=1; PKG_FLAGS+=("$arg") ;;
    --uninstall) UNINSTALL=1 ;;
    --no-fx) NO_FX=1 ;;
    -h|--help) sed -n '2,8s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '  \033[38;2;54;249;246m›\033[0m %s\n' "$*"; }
warn() { printf '  \033[38;2;254;222;93m▲\033[0m %s\n' "$*" >&2; }
# shellcheck source=install-fx.sh
. "$DOT/linux/install-fx.sh"
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
  if [[ -L $dest && $(readlink "$dest") == "$DOT/"* ]]; then command rm -f "$dest"  # ours, from an older layout
  elif [[ -e $dest || -L $dest ]]; then backup "$dest"; fi
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
  if [[ $EUID -ne 0 ]]; then
    sudo=(sudo)
    # ask for the password now, then keep it fresh: steps run behind spinners, where a sudo prompt would hide
    sudo -v
    ( while sleep 50; do kill -0 $$ 2>/dev/null || exit; sudo -n true; done ) >/dev/null 2>&1 &
  fi
  # packages.py needs the system python3 + PyYAML (not pyenv's python) to read packages.yaml, and gpg for apt repo keys
  if ! /usr/bin/python3 -c 'import yaml' 2>/dev/null || ! have gpg; then
    spin "apt update" "${sudo[@]}" apt-get update -qq
    spin "python3-yaml, gnupg" "${sudo[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-yaml gnupg
  fi
  /usr/bin/python3 -I "$DOT/linux/packages.py" linux "${PKG_FLAGS[@]}"
  is_wsl && have winget.exe && /usr/bin/python3 -I "$DOT/linux/packages.py" windows "${PKG_FLAGS[@]}"

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

# repo path, then where it is linked under $HOME
LINKS=(
  linux/zsh/zshrc                     .zshrc
  linux/zsh/zshenv                    .zshenv
  linux/zsh/zprofile                  .zprofile
  linux/zsh/zsh_aliases               .zsh_aliases
  linux/zsh/zsh_plugins.txt           .zsh_plugins.txt
  linux/starship/starship.toml        .config/starship.toml
  linux/starship/starship-status.toml .config/starship-status.toml
  linux/byobu/profile.tmux            .config/byobu/profile.tmux
  linux/byobu/color.tmux              .config/byobu/color.tmux
  linux/byobu/backend                 .config/byobu/backend
  linux/byobu/bin                     .config/byobu/bin
  linux/vim/vimrc                     .vimrc
)
link_configs() {
  local i
  for ((i = 0; i < ${#LINKS[@]}; i += 2)); do link "${LINKS[i]}" "$HOME/${LINKS[i + 1]}"; done
}

bootstrap_plugins() {
  local p
  for p in tmux-resurrect tmux-continuum; do
    if [[ ! -d $HOME/.tmux/plugins/$p ]] && have git; then
      spin "tmux plugin $p" git clone -q --depth=1 "https://github.com/tmux-plugins/$p" "$HOME/.tmux/plugins/$p"
    fi
  done
  if [[ ! -d $HOME/.antidote ]] && have git; then
    spin "antidote" git clone -q --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
  if have zsh && [[ -r $HOME/.antidote/antidote.zsh ]]; then
    spin "zsh plugins" zsh -c 'source ~/.antidote/antidote.zsh && antidote bundle <~/.zsh_plugins.txt >~/.zsh_plugins.zsh'
  fi
  if have vim && have curl; then
    if [[ ! -f $HOME/.vim/autoload/plug.vim ]]; then
      spin "vim-plug" curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    spin "vim plugins" vim -Nu "$HOME/.vimrc" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' || true
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
  python3 -I "$DOT/windows/terminal/merge.py" "$settings" "$DOT/windows/terminal/settings.patch.json"
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
win_env() {  # win_env <name>: a Windows environment variable, empty if unset
  (cd /mnt/c && cmd.exe /c "echo %$1%" 2>/dev/null) | tr -d '\r' | grep -vx "%$1%" || true
}
YASBC="/mnt/c/Program Files/YASB/yasbc.exe"
yasb_same() {  # yasb_same <dir>: it holds this repo's YASB files (line endings aside; YASB's own files ignored)
  local f
  for f in "$DOT"/windows/yasb/*; do
    [[ -f $1/${f##*/} ]] && diff -q <(tr -d '\r' <"$f") <(tr -d '\r' <"$1/${f##*/}") >/dev/null || return 1
  done
}

# YASB (Windows status bar): this repo's config in YASB's default folder, started at sign-in, restarted on changes.
# A Windows clone set up by windows/install.ps1 points YASB at itself instead (YASB_CONFIG_HOME); then this skips.
configure_yasb() {
  is_wsl && have cmd.exe && [[ -x $YASBC ]] || return 0
  [[ -z $(win_env YASB_CONFIG_HOME) ]] || return 0
  local dir; dir="$(wslpath "$(win_env USERPROFILE)")/.config/yasb"
  yasb_same "$dir" && return 0
  mkdir -p "$BACKUP"
  if [[ -d $dir ]]; then cp -r "$dir" "$BACKUP/yasb-config"; else : >"$BACKUP/yasb-config.created"; fi  # for --uninstall
  mkdir -p "$dir" && cp "$DOT"/windows/yasb/* "$dir/"
  spin "YASB: config, autostart, restart" bash -c '"$1" enable-autostart; "$1" stop; "$1" start' _ "$YASBC"
}

configure_git() {
  have delta && have git || return 0
  git config --global --fixed-value --unset-all include.path "$DOT/git/delta.gitconfig" 2>/dev/null || true  # pre-3.0 path
  git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/linux/git/delta.gitconfig" && return 0
  git config --global --add include.path "$DOT/linux/git/delta.gitconfig"
  log "git: delta pager"
}

# ---------------------------------------------------------------- uninstall
# Undo everything above. Only removes what is ours (links into this repo, our plugin clones, packages this
# installer recorded); everything it replaced comes back from the oldest backup, i.e. from before the first install.
oldest_backup() {  # oldest_backup <path relative to the backup dirs>: prints it, if any
  local b
  for b in "$HOME"/.dotfiles-backup/*/"$1"; do
    if [[ -e $b || -L $b ]]; then printf '%s' "$b"; return 0; fi
  done
}

restore() {  # restore <path relative to $HOME>: put its oldest backup back, if its place is free
  local b; b=$(oldest_backup "$1")
  [[ -n $b && ! -e $HOME/$1 && ! -L $HOME/$1 ]] || return 0
  mkdir -p "$(dirname "$HOME/$1")"
  cp -a "$b" "$HOME/$1"
  log "restored ~/$1"
}

uninstall_packages() {
  have apt-get && /usr/bin/python3 -c 'import yaml' 2>/dev/null || { warn "packages: not on apt or no python3-yaml; skipped"; return 0; }
  if [[ $EUID -ne 0 ]]; then
    sudo -v
    ( while sleep 50; do kill -0 $$ 2>/dev/null || exit; sudo -n true; done ) >/dev/null 2>&1 &
  fi
  /usr/bin/python3 -I "$DOT/linux/packages.py" linux --purge "${PKG_FLAGS[@]}"
  if is_wsl && have winget.exe; then /usr/bin/python3 -I "$DOT/linux/packages.py" windows --purge "${PKG_FLAGS[@]}"; fi
}

uninstall_configs() {
  local i dest
  for ((i = 0; i < ${#LINKS[@]}; i += 2)); do
    dest=$HOME/${LINKS[i + 1]}
    if [[ -L $dest && $(readlink "$dest") == "$DOT/"* ]]; then command rm -f "$dest"; log "unlinked ~/${LINKS[i + 1]}"; fi
  done
  command rm -rf "$HOME/.antidote" "$HOME/.zsh_plugins.zsh" "$HOME/.tmux/plugins/tmux-resurrect" \
    "$HOME/.tmux/plugins/tmux-continuum" "$HOME/.vim/plugged" "$HOME/.vim/autoload/plug.vim"
  rmdir "$HOME/.vim/autoload" "$HOME/.vim" "$HOME/.tmux/plugins" "$HOME/.tmux" "$HOME/.config/byobu" 2>/dev/null || true
  log "removed plugins (antidote, tmux-resurrect, tmux-continuum, vim-plug)"
  # what the links and the old-setup cleanup moved aside
  for ((i = 1; i < ${#LINKS[@]}; i += 2)); do restore "${LINKS[i]}"; done
  for i in .zlogin .zlogout .zpreztorc .vim; do restore "$i"; done
}

uninstall_system() {
  if have git && git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/linux/git/delta.gitconfig"; then
    git config --global --fixed-value --unset-all include.path "$DOT/linux/git/delta.gitconfig"
    log "git: delta pager include removed"
  fi
  is_wsl && have cmd.exe || return 0
  local appdata profile settings f b
  appdata=$(cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')
  settings="$(wslpath "$appdata")/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  b=$(oldest_backup windows-terminal-settings.json)
  if [[ -n $b && -f $settings ]]; then
    mkdir -p "$BACKUP"; cp "$settings" "$BACKUP/windows-terminal-settings.json"  # today's, in case
    cp "$b" "$settings"
    log "Windows Terminal: settings from before the first install restored (today's kept in $BACKUP)"
  fi
  profile=$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
  f=$profile/.wslconfig b=$(oldest_backup wslconfig)
  if [[ -n $b ]]; then
    cp "$b" "$f"; log "WSL: .wslconfig restored (apply with 'wsl --shutdown')"
  elif [[ -f $f && $(tr -d '\r' <"$f") == $'[wsl2]\nnetworkingMode=mirrored' ]]; then  # created by install.sh
    command rm -f "$f"; log "WSL: .wslconfig removed (apply with 'wsl --shutdown')"
  fi
  local yasb=0 dir=$profile/.config/yasb
  b=$(oldest_backup yasb-config)
  if [[ -n $b ]]; then
    command rm -rf "$dir"; cp -r "$b" "$dir"; yasb=1; log "YASB: config from before the first install restored"
  elif [[ -n $(oldest_backup yasb-config.created) ]]; then  # ours: there was none before
    command rm -rf "$dir"; yasb=1; log "YASB: config removed"
  fi
  if [[ -n $(win_env YASB_CONFIG_HOME) ]]; then
    powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('YASB_CONFIG_HOME', \$null, 'User')" >/dev/null
    yasb=1; log "YASB: YASB_CONFIG_HOME removed"
  fi
  if (( yasb )) && [[ -x $YASBC ]]; then "$YASBC" disable-autostart >/dev/null 2>&1 || true; log "YASB: autostart off"; fi
}

uninstall() {
  typed "  ✦ dotfiles: uninstall ✦"
  section packages; uninstall_packages
  section configs; uninstall_configs
  section system; uninstall_system
  printf '\n'
  log "done. Backups stay in ~/.dotfiles-backup; saved byobu tabs in ~/.local/share/tmux/resurrect"
  if [[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]]; then log "default shell is still zsh; to change it: chsh -s /bin/bash"; fi
  log "to finish: rm -rf $DOT$(is_wsl && printf ' (and %%USERPROFILE%%\\dotfiles on Windows)')"
}

if [[ $UNINSTALL -eq 1 ]]; then uninstall; exit 0; fi
intro
if [[ $PACKAGES -eq 1 ]]; then section packages; install_packages; fi
section configs
retire_old_setup
link_configs
section plugins
bootstrap_plugins
section system
patch_windows_terminal
configure_wsl
configure_yasb
configure_git
[[ -d $BACKUP ]] && log "backups in $BACKUP"
outro
