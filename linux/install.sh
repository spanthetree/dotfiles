#!/usr/bin/env bash
# Linux/WSL installer (run it through ../install.cmd): symlinks configs into $HOME. Safe to re-run.
#   ./install.cmd             install missing tools from packages.yaml, uninstall removed ones (Debian/Ubuntu),
#                             link configs, bootstrap antidote + vim-plug, patch Windows Terminal (WSL)
#     --no-packages  skip the packages step (configs only)
#     --adopt   once per existing machine: treat everything already installed from packages.yaml as managed
#     --yes     uninstall removed packages without asking
#   ./install.cmd --uninstall remove it all: links, plugins, settings, packages it installed (asks); restores backups
#   ./install.cmd --no-fx     plain output, no spinners (also off when output isn't a terminal, or NO_FX=1)
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # the repo
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
PACKAGES=1
UNINSTALL=0
PKG_FLAGS=()
for arg in "$@"; do
  case $arg in
    --packages) ;;  # the default now; kept so older commands still work
    --no-packages) PACKAGES=0 ;;
    --adopt|--yes) PKG_FLAGS+=("$arg") ;;
    --uninstall) UNINSTALL=1 ;;
    --no-fx) NO_FX=1 ;;
    -h|--help) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
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

# ---------------------------------------------------------------- sudo
# One password for the whole run. Asked now, then kept fresh: steps run behind spinners, where a prompt would hide.
# Some tools drop sudo's cached password when they're done (hyprpm runs `sudo -k`), so the next step would ask again;
# for this run a `sudo` first in PATH ignores that, and the cache is dropped once, at the end.
SUDO_SHIM=
sudo_session() {
  [[ $EUID -ne 0 && -z $SUDO_SHIM ]] || return 0
  local real; real=$(command -v sudo)
  sudo -v
  SUDO_SHIM=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-sudo.XXXXXX")
  printf '%s\n' '#!/bin/sh' \
    '# dotfiles installer (this run only): keep the cached password; see sudo_session in linux/install.sh' \
    'case "$1" in -K|--remove-timestamp) exit 0 ;; -k|--reset-timestamp) shift; [ $# -eq 0 ] && exit 0 ;; esac' \
    "exec $real \"\$@\"" > "$SUDO_SHIM/sudo"
  chmod 755 "$SUDO_SHIM/sudo"
  export PATH="$SUDO_SHIM:$PATH"
  trap 'sudo_end; fx_exit' EXIT
  ( while sleep 50; do kill -0 $$ 2>/dev/null || exit; "$real" -n true; done ) >/dev/null 2>&1 &
}
sudo_end() {
  [[ -n $SUDO_SHIM ]] || return 0
  PATH=${PATH//"$SUDO_SHIM:"/}; hash -r  # the real sudo again (bash remembered the shim's path)
  command rm -rf "$SUDO_SHIM"; SUDO_SHIM=
  sudo -k  # what those tools asked for
}

# ---------------------------------------------------------------- packages
install_packages() {
  if ! have apt-get; then
    warn "packages: supports Debian/Ubuntu only; install what you need from packages.yaml by hand"
    return 0
  fi
  local sudo=()
  if [[ $EUID -ne 0 ]]; then
    sudo=(sudo)
    sudo_session
  fi
  # packages.py needs the system python3 + PyYAML (not pyenv's python) to read packages.yaml, and gpg for apt repo keys
  if ! /usr/bin/python3 -c 'import yaml' 2>/dev/null || ! have gpg; then
    spin "apt update" "${sudo[@]}" apt-get update -qq
    spin "python3-yaml, gnupg" "${sudo[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-yaml gnupg
  fi
  # a Ctrl-C mid-install leaves dpkg half done, and apt refuses to run until it is finished
  if [[ -n $(ls -A /var/lib/dpkg/updates 2>/dev/null) ]]; then spin "dpkg --configure -a" "${sudo[@]}" dpkg --configure -a; fi
  /usr/bin/python3 -I "$DOT/linux/packages.py" linux "${PKG_FLAGS[@]}"
  is_wsl && have winget.exe && /usr/bin/python3 -I "$DOT/linux/packages.py" windows "${PKG_FLAGS[@]}"

  if [[ $(getent passwd "$(id -un)" | cut -d: -f7) != */zsh ]]; then
    log "default shell -> zsh"
    "${sudo[@]}" chsh -s "$(command -v zsh)" "$(id -un)"
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
  linux/byobu/keybindings.tmux        .config/byobu/keybindings.tmux
  linux/byobu/backend                 .config/byobu/backend
  linux/byobu/bin                     .config/byobu/bin
  linux/vim/vimrc                     .vimrc
  linux/terminator/config             .config/terminator/config
  linux/kitty/dotfiles.conf           .config/kitty/dotfiles.conf
  linux/kitty/theme.conf              .config/kitty/theme.conf
  linux/hypr/dotfiles.lua             .config/hypr/dotfiles.lua
  linux/hypr/windows.sh               .config/hypr/dotfiles-windows.sh
  linux/hyprshell/config.toml         .config/hyprshell/config.toml
)
link_configs() {
  local i
  for ((i = 0; i < ${#LINKS[@]}; i += 2)); do
    [[ ${LINKS[i + 1]} == .config/kitty/* ]] && ! have kitty && continue  # kitty: packages.yaml, on a desktop
    [[ ${LINKS[i + 1]} == .config/hypr/* ]] && ! have Hyprland && continue  # so does Hyprland
    [[ ${LINKS[i + 1]} == .config/hyprshell/* && ! -x $HOME/.local/bin/hyprshell ]] && continue  # built only on GTK 4.18+
    link "${LINKS[i]}" "$HOME/${LINKS[i + 1]}"
  done
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

# kitty: include our dotfiles.conf (byobu settings + theme.conf) last in each kitty.conf kitty reads, so it wins
# and every session looks the same; the rest of those files stays the user's (or a desktop setup's).
#   ~/.config/kitty/kitty.conf: kitty's default, e.g. Ubuntu's GNOME (created if missing)
#   ~/.config/hypr/UserConfigs/kitty.conf: the Hyprland desktop setup's, if there; it points $KITTY_CONFIG_DIRECTORY
#     there under Hyprland
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
KITTY_HYPR_CONF="$HOME/.config/hypr/UserConfigs/kitty.conf"
KITTY_INCLUDE="include ~/.config/kitty/dotfiles.conf"
KITTY_CONFS=("$KITTY_CONF" "$KITTY_HYPR_CONF")  # every place we may have added it
KITTY_OLD_INCLUDE="include dotfiles.conf"  # before 4.2: relative, so only right in ~/.config/kitty
# Unreleased: ~/.config/kitty/kitty.conf included the Hyprland desktop setup's kitty.conf for its look; theme.conf has it now
KITTY_HYPR_INCLUDE="include ~/.config/hypr/UserConfigs/kitty.conf"
unkitty() {  # unkitty <kitty.conf> <line>...: remove the lines; delete the file (and its empty dir) if only they were in it
  local f=$1 rest; shift
  local args=(); for l; do args+=(-e "$l"); done
  grep -qxF "${args[@]}" "$f" 2>/dev/null || return 1
  rest=$(grep -vxF "${args[@]}" "$f" || true)
  if [[ -z ${rest//[[:space:]]/} ]]; then command rm -f "$f"; rmdir "$(dirname "$f")" 2>/dev/null || true
  else printf '%s\n' "$rest" >| "$f"; fi
}
configure_kitty() {
  have kitty || return 0
  unkitty "$KITTY_CONF" "$KITTY_OLD_INCLUDE" "$KITTY_HYPR_INCLUDE" || true
  local f
  for f in "${KITTY_CONFS[@]}"; do
    [[ $f == "$KITTY_CONF" || -f $f ]] || continue  # the desktop setup's: only if it's there
    grep -qxF "$KITTY_INCLUDE" "$f" 2>/dev/null && continue
    mkdir -p "$(dirname "$f")"
    printf '\n%s\n' "$KITTY_INCLUDE" >> "$f"
    log "kitty: dotfiles.conf included from ${f/#$HOME/\~}"
  done
}

# Hyprland: load our dotfiles.lua from the end of the desktop setup's user_keybinds.lua (its updates keep that file)
HYPR_KEYS="$HOME/.config/hypr/UserConfigs/user_keybinds.lua"
HYPR_INCLUDE='local ok, err = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/dotfiles.lua"); if not ok then print("[WARN] dotfiles.lua: " .. tostring(err)) end -- dotfiles'
HYPR_OLD_INCLUDE='pcall(dofile, os.getenv("HOME") .. "/.config/hypr/dotfiles.lua") -- dotfiles'  # before 4.2: errors unseen
# Waybar: custom/minimized (count of minimized windows, click for the restore menu; linux/hypr/windows.sh).
# Defined in the desktop setup's UserModules (its updates keep that file) and listed first in modules-right of
# every layout that includes UserModules, so switching layouts keeps it.
WAYBAR_DIR="$HOME/.config/hypr/waybar"
WAYBAR_MODULE='"custom/minimized": {"exec": "$HOME/.config/hypr/dotfiles-windows.sh count", "return-type": "json", "interval": 5, "signal": 11, "on-click": "$HOME/.config/hypr/dotfiles-windows.sh restore"}, // dotfiles'
WAYBAR_ITEM='	"custom/minimized", // dotfiles'
# fcitx5's input methods for Hyprland: US keyboard and Mozc (fcitx5 alone starts with the keyboard only)
# The overview (Super-A, tap Super): one row of 5 workspaces instead of 2 x 5; its own docs say to edit this file
QS_OVERVIEW="$HOME/.config/quickshell/overview/common/Config.qml"
QS_ROWS='            property int rows: 2'
QS_OUR_ROWS='            property int rows: 1  // dotfiles: 5 workspaces (was 2)'
# The desktop setup's waybar opens the wallpaper menu as UserScripts/WallpaperSelect.sh, but ships it in scripts/
# (its bug, as of Hyprland-Dots 2026-11): a link there makes those clicks work. Its updates keep UserScripts.
WALLSEL_LINK="$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"
WALLSEL="$HOME/.config/hypr/scripts/WallpaperSelect.sh"
FCITX_PROFILE="$HOME/.config/fcitx5/profile"
FCITX_PROFILE_TEXT='[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=mozc

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=mozc
# Layout
Layout=

[GroupOrder]
0=Default'
# Line edits that leave the rest of the file byte for byte (a missing final newline stays missing), so uninstalling
# gives back the original. perl is in every Debian/Ubuntu (perl-base).
# insert_after <file> <perl regex> <line>: add the line after the first line matching the regex
insert_after() {
  RE=$2 L=$3 perl -i -pe 'if (!$d && /$ENV{RE}/) { $_ .= "\n" unless /\n\z/; $_ .= "$ENV{L}\n"; $d = 1 }' "$1"
}
# drop_line <file> <line>: remove that exact line (and the blank line before it, if both were appended at the end);
# return 1 if it wasn't there
drop_line() {
  grep -qxF -e "$2" "$1" 2>/dev/null || return 1
  L=$2 perl -0777 -i -pe 's/\n\n\Q$ENV{L}\E\n\z/\n/ or s/^\Q$ENV{L}\E(\n|\z)//mg' "$1"
}
hypr_version() { Hyprland --version 2>/dev/null | awk 'NR == 1 {print $2}'; }
configure_hyprland() {
  have Hyprland || return 0
  local v; v=$(hypr_version)
  if [[ -n $v ]] && ! dpkg --compare-versions "$v" ge 0.55 2>/dev/null; then  # Lua config: 0.55+
    warn "Hyprland $v is too old for dotfiles.lua (needs 0.55+, e.g. from ppa:cppiber/hyprland); Hyprland settings skipped"
    return 0
  fi
  [[ -f $HYPR_KEYS ]] || { warn "Hyprland: no ${HYPR_KEYS/#$HOME/\~} (desktop setup not copied yet?); Hyprland settings skipped"; return 0; }
  drop_line "$HYPR_KEYS" "$HYPR_OLD_INCLUDE" || true
  if ! grep -qxF "$HYPR_INCLUDE" "$HYPR_KEYS"; then
    printf '\n%s\n' "$HYPR_INCLUDE" >> "$HYPR_KEYS"
    log "Hyprland: dotfiles.lua loaded from user_keybinds.lua"
  fi
  local changed='' f
  if [[ -f $WAYBAR_DIR/UserModules ]] && ! grep -qxF "$WAYBAR_MODULE" "$WAYBAR_DIR/UserModules"; then
    if grep -qx '[[:space:]]*{[[:space:]]*' "$WAYBAR_DIR/UserModules"; then
      insert_after "$WAYBAR_DIR/UserModules" '^[[:space:]]*\{[[:space:]]*$' "$WAYBAR_MODULE"; changed=1
    else warn "waybar: UserModules has no '{' line of its own; minimized-windows module not added"; fi
  fi
  if grep -qxF "$WAYBAR_MODULE" "$WAYBAR_DIR/UserModules" 2>/dev/null; then
    for f in "$WAYBAR_DIR"/configs/*; do
      [[ -f $f && ! -L $f ]] && grep -q 'waybar/UserModules' "$f" && ! grep -qxF "$WAYBAR_ITEM" "$f" || continue
      grep -q '"modules-right"[[:space:]]*:[[:space:]]*\[[[:space:]]*$' "$f" || continue
      insert_after "$f" '"modules-right"[[:space:]]*:[[:space:]]*\[[[:space:]]*$' "$WAYBAR_ITEM"; changed=1
    done
  fi
  if [[ -n $changed ]]; then
    pkill -USR2 -x waybar 2>/dev/null || true  # reload its config
    log "waybar: minimized-windows indicator"
  fi
  if grep -qxF -e "$QS_ROWS" "$QS_OVERVIEW" 2>/dev/null; then
    A=$QS_ROWS B=$QS_OUR_ROWS perl -i -pe 's/^\Q$ENV{A}\E$/$ENV{B}/' "$QS_OVERVIEW"  # quickshell reloads it by itself
    log "overview: 5 workspaces"
  fi
  if [[ -x $WALLSEL && ! -e $WALLSEL_LINK && ! -L $WALLSEL_LINK ]] && grep -rqF 'UserScripts/WallpaperSelect.sh' "$WAYBAR_DIR" 2>/dev/null; then
    mkdir -p "$(dirname "$WALLSEL_LINK")" && ln -s "$WALLSEL" "$WALLSEL_LINK"
    log "waybar: wallpaper menu clicks fixed (UserScripts/WallpaperSelect.sh -> scripts/)"
  fi
  if [[ -x $HOME/.local/bin/hyprshell ]]; then  # unknown keys are errors in its config: say so now, not at login
    if "$HOME/.local/bin/hyprshell" -c "$DOT/linux/hyprshell/config.toml" config check >/dev/null 2>&1; then
      log "hyprshell: Alt-Tab and Super-Space (log in to Hyprland again, or run: hyprshell run)"
    else warn "hyprshell: linux/hyprshell/config.toml has errors: hyprshell -c ~/.config/hyprshell/config.toml config check"; fi
  fi
  if have fcitx5 && [[ ! -e $FCITX_PROFILE ]]; then
    mkdir -p "$(dirname "$FCITX_PROFILE")"
    printf '%s\n' "$FCITX_PROFILE_TEXT" >| "$FCITX_PROFILE"
    log "fcitx5: US keyboard + Mozc (Ctrl-Space switches)"
  fi
}
uninstall_hyprland() {
  if drop_line "$HYPR_KEYS" "$HYPR_INCLUDE" || drop_line "$HYPR_KEYS" "$HYPR_OLD_INCLUDE"; then
    log "Hyprland: include removed from user_keybinds.lua"
  fi
  local removed='' f
  for f in "$WAYBAR_DIR/UserModules" "$WAYBAR_DIR"/configs/*; do
    [[ -f $f ]] || continue
    drop_line "$f" "$WAYBAR_MODULE" && removed=1
    drop_line "$f" "$WAYBAR_ITEM" && removed=1
  done
  if [[ -n $removed ]]; then
    pkill -USR2 -x waybar 2>/dev/null || true
    log "waybar: minimized-windows indicator removed"
  fi
  if [[ -L $WALLSEL_LINK && $(readlink "$WALLSEL_LINK") == "$WALLSEL" ]]; then
    command rm -f "$WALLSEL_LINK"; log "waybar: wallpaper menu link removed"
  fi
  if grep -qxF -e "$QS_OUR_ROWS" "$QS_OVERVIEW" 2>/dev/null; then
    A=$QS_OUR_ROWS B=$QS_ROWS perl -i -pe 's/^\Q$ENV{A}\E$/$ENV{B}/' "$QS_OVERVIEW"
    log "overview: back to 10 workspaces"
  fi
  # ours unless changed since: compare without fcitx5's comments and blank lines (it rewrites the file)
  local strip='/^#/d; /^[[:space:]]*$/d'
  if [[ -f $FCITX_PROFILE ]] && [[ $(sed "$strip" "$FCITX_PROFILE") == "$(sed "$strip" <<<"$FCITX_PROFILE_TEXT")" ]]; then
    command rm -f "$FCITX_PROFILE"; rmdir "$(dirname "$FCITX_PROFILE")" 2>/dev/null || true
    log "fcitx5: input-method profile removed"
  fi
}

# VS Code under Hyprland: Electron picks its secret store from XDG_CURRENT_DESKTOP, doesn't know Hyprland,
# and says "An OS keyring couldn't be identified". Point it at gnome-keyring (libsecret) in argv.json (JSONC).
VSCODE_ARGV="$HOME/.vscode/argv.json"
VSCODE_LINE='	"password-store": "gnome-libsecret", // dotfiles'
configure_vscode() {
  have Hyprland && have code || return 0
  grep -qxF -e "$VSCODE_LINE" -e "${VSCODE_LINE/,/}" "$VSCODE_ARGV" 2>/dev/null && return 0
  if grep -q '"password-store"' "$VSCODE_ARGV" 2>/dev/null; then warn "VS Code: password-store already set in argv.json, left alone"; return 0; fi
  if [[ ! -f $VSCODE_ARGV ]]; then
    mkdir -p "$(dirname "$VSCODE_ARGV")"
    printf '{\n%s\n}\n' "${VSCODE_LINE/,/}" >| "$VSCODE_ARGV"  # no trailing comma when it's the only key
  elif grep -qx '[[:space:]]*{[[:space:]]*' "$VSCODE_ARGV"; then
    local argv; argv=$(awk -v l="$VSCODE_LINE" '!done && /^[[:space:]]*\{[[:space:]]*$/ {print; print l; done=1; next} 1' "$VSCODE_ARGV")
    printf '%s\n' "$argv" >| "$VSCODE_ARGV"
  else warn "VS Code: argv.json has no '{' line of its own, left alone"; return 0; fi
  log "VS Code: gnome-libsecret password store (restart VS Code)"
}

# Japanese input under Ubuntu's GNOME, like Hyprland's fcitx5: ibus Mozc in place of Anthy (or added), and Ctrl-Space
# (in place of Super-Space) to switch. The old values go to the backup dir, for --uninstall.
GNOME_IS=org.gnome.desktop.input-sources
GNOME_KB=org.gnome.desktop.wm.keybindings
gset() {  # gset <schema> <key> <value> <backup name>: set it, keeping the old value (and ours) in the backup dir
  local cur; cur=$(gsettings get "$1" "$2") || return 1
  [[ $cur == "$3" ]] && return 1
  mkdir -p "$BACKUP"
  printf '%s\n' "$cur" >| "$BACKUP/$4"; printf '%s\n' "$3" >| "$BACKUP/$4.ours"
  gsettings set "$1" "$2" "$3"
}
gunset() {  # gunset <schema> <key> <backup name>: put the old value back, unless it was changed since
  local b ours; b=$(oldest_backup "$3")
  [[ -n $b && -f $b.ours ]] || return 1
  ours=$(<"$b.ours")
  [[ $(gsettings get "$1" "$2" 2>/dev/null) == "$ours" ]] || return 1
  gsettings set "$1" "$2" "$(<"$b")"
}
configure_gnome_input() {
  have gnome-shell && have gsettings && [[ -f /usr/share/ibus/component/mozc.xml ]] || return 0
  gsettings list-keys "$GNOME_IS" >/dev/null 2>&1 || return 0  # not `list-schemas | grep -q`: SIGPIPE + pipefail
  local s k b changed=''
  s=$(gsettings get "$GNOME_IS" sources) || return 0
  if [[ $s != *"('ibus', 'mozc-jp')"* ]]; then
    s=${s//"('ibus', 'anthy')"/"('ibus', 'mozc-jp')"}
    if [[ $s != *mozc-jp* ]]; then
      if [[ $s == *'[]' ]]; then s="[('xkb', 'us'), ('ibus', 'mozc-jp')]"; else s="${s%]}, ('ibus', 'mozc-jp')]"; fi
    fi
    gset "$GNOME_IS" sources "$s" gnome-input-sources && changed=1
  fi
  k=$(gsettings get "$GNOME_KB" switch-input-source) b=$(gsettings get "$GNOME_KB" switch-input-source-backward)
  if [[ $k != *"'<Control>space'"* ]]; then
    if [[ $k == *"'<Super>space'"* ]]; then k=${k//"'<Super>space'"/"'<Control>space'"}
    elif [[ $k == *'[]' ]]; then k="['<Control>space']"; else k="['<Control>space', ${k#\[}"; fi
    gset "$GNOME_KB" switch-input-source "$k" gnome-switch-input-source && changed=1
  fi
  if [[ $b != *"'<Shift><Control>space'"* ]]; then
    if [[ $b == *"'<Shift><Super>space'"* ]]; then b=${b//"'<Shift><Super>space'"/"'<Shift><Control>space'"}
    elif [[ $b == *'[]' ]]; then b="['<Shift><Control>space']"; else b="['<Shift><Control>space', ${b#\[}"; fi
    gset "$GNOME_KB" switch-input-source-backward "$b" gnome-switch-input-source-backward && changed=1
  fi
  [[ -n $changed ]] && log "GNOME: Mozc for Japanese, Ctrl-Space switches"
  return 0
}
uninstall_gnome_input() {
  have gsettings || return 0
  local changed=''
  gunset "$GNOME_IS" sources gnome-input-sources && changed=1
  gunset "$GNOME_KB" switch-input-source gnome-switch-input-source && changed=1
  gunset "$GNOME_KB" switch-input-source-backward gnome-switch-input-source-backward && changed=1
  [[ -n $changed ]] && log "GNOME: input sources and switch key restored"
  return 0
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
  sudo_session
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
  rmdir "$HOME/.vim/autoload" "$HOME/.vim" "$HOME/.tmux/plugins" "$HOME/.tmux" "$HOME/.config/byobu" "$HOME/.config/terminator" 2>/dev/null || true
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
  local kc; for kc in "${KITTY_CONFS[@]}"; do
    if unkitty "$kc" "$KITTY_INCLUDE" "$KITTY_OLD_INCLUDE" "$KITTY_HYPR_INCLUDE"; then log "kitty: include removed from ${kc/#$HOME/\~}"; fi
  done
  uninstall_hyprland
  uninstall_gnome_input
  if grep -qxF -e "$VSCODE_LINE" -e "${VSCODE_LINE/,/}" "$VSCODE_ARGV" 2>/dev/null; then
    local argv; argv=$(grep -vxF -e "$VSCODE_LINE" -e "${VSCODE_LINE/,/}" "$VSCODE_ARGV" || true)
    if [[ -z ${argv//[[:space:]\{\}]/} ]]; then command rm -f "$VSCODE_ARGV"  # only our key: we created it
    else printf '%s\n' "$argv" >| "$VSCODE_ARGV"; fi
    log "VS Code: password-store removed from argv.json"
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
  if [[ $(getent passwd "$(id -un)" | cut -d: -f7) == */zsh ]]; then log "default shell is still zsh; to change it: chsh -s /bin/bash"; fi
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
configure_kitty
configure_hyprland
configure_vscode
configure_gnome_input
[[ -d $BACKUP ]] && log "backups in $BACKUP"
outro
