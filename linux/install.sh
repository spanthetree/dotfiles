#!/usr/bin/env bash
# Linux/WSL installer (run it through ../install.cmd): symlinks configs into $HOME. Safe to re-run.
#   ./install.cmd             install missing tools from packages.yaml, uninstall removed ones (Debian/Ubuntu),
#                             link configs, bootstrap antidote + vim-plug, patch Windows Terminal (WSL)
#     --no-packages  skip the packages step (configs only)
#     --adopt   once per existing machine: treat everything already installed from packages.yaml as managed
#     --yes     uninstall removed packages without asking
#     --cosmic  also install the COSMIC desktop (kept on later runs); --no-cosmic drops it again
#     --hyprland  also install the Hyprland desktop setup (Ubuntu 26.04+; kept on later runs); --no-hyprland drops it
#   ./install.cmd --uninstall remove it all: links, plugins, settings, packages it installed (asks); restores backups
#   ./install.cmd --no-fx     plain output, no spinners (also off when output isn't a terminal, or NO_FX=1)
#   ./install.cmd --check     change nothing: report what differs from this repo (links, packages, settings);
#                             exits 1 when something does
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # the repo
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
PACKAGES=1
UNINSTALL=0
CHECK=0
PKG_FLAGS=()
# A desktop's settings and links are removed only when asked (--no-cosmic / --no-hyprland, or --uninstall), never
# because its programs are missing: an apt mishap that removed COSMIC mid-run once also wiped its settings.
DROP_COSMIC=0 DROP_HYPRLAND=0
for arg in "$@"; do
  case $arg in
    --packages) ;;  # the default now; kept so older commands still work
    --no-packages) PACKAGES=0 ;;
    --adopt|--yes|--cosmic|--no-cosmic|--hyprland|--no-hyprland) PKG_FLAGS+=("$arg")
      case $arg in --no-cosmic) DROP_COSMIC=1 ;; --no-hyprland) DROP_HYPRLAND=1 ;; esac ;;
    --uninstall) UNINSTALL=1 ;;
    --check) CHECK=1 ;;
    --no-fx) export NO_FX=1 ;;  # exported: packages.py draws its own spinners
    -h|--help) sed -n '2,13s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '  \033[38;2;54;249;246m›\033[0m %s\n' "$*"; }
warn() { printf '  \033[38;2;254;222;93m▲\033[0m %s\n' "$*" >&2; }
# shellcheck source=install-fx.sh
. "$DOT/linux/install-fx.sh"
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
# hyprpm and hyprctl find Hyprland through HYPRLAND_INSTANCE_SIGNATURE. A shell that outlived a Hyprland restart
# (byobu's server keeps the environment it started with) names a dead instance, and hyprpm then fails with
# "failed to get the current hyprland version". Use the running instance instead (none: plugins load at login).
fix_hypr_signature() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && have hyprctl || return 0
  hyprctl version >/dev/null 2>&1 && return 0
  local d
  for d in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/; do
    [[ -S $d.socket.sock ]] || continue
    if HYPRLAND_INSTANCE_SIGNATURE=$(basename "$d") hyprctl version >/dev/null 2>&1; then
      export HYPRLAND_INSTANCE_SIGNATURE; HYPRLAND_INSTANCE_SIGNATURE=$(basename "$d"); return 0
    fi
  done
  unset HYPRLAND_INSTANCE_SIGNATURE
}
# byobu's server keeps the environment it started with, so after pyenv, rbenv or /usr/local/go are removed (mise
# replaced them) its new tabs still get their variables and PATH entries. zshenv drops them in zsh; this fixes the
# server itself, for everything else it starts.
fix_tmux_env() {
  have tmux && tmux has-session 2>/dev/null || return 0
  local d e v p changed=0 gone=() parts=() keep=()
  for d in "$HOME/.pyenv" "$HOME/.rbenv" /usr/local/go; do [[ -d $d ]] || gone+=("$d"); done
  ((${#gone[@]})) || return 0
  for v in $(tmux show-environment -g | sed -n 's/^\(\(PYENV\|RBENV\)_[A-Za-z0-9_]*\)=.*/\1/p'); do
    [[ $v == PYENV_* && -d $HOME/.pyenv || $v == RBENV_* && -d $HOME/.rbenv ]] && continue
    tmux set-environment -g -u "$v"; changed=1
  done
  if p=$(tmux show-environment -g PATH 2>/dev/null) && [[ $p == PATH=* ]]; then
    IFS=: read -ra parts <<<"${p#PATH=}"
    for e in "${parts[@]}"; do
      for d in "${gone[@]}"; do [[ $e == "$d"/* ]] && continue 2; done
      keep+=("$e")
    done
    if ((${#keep[@]} < ${#parts[@]})); then tmux set-environment -g PATH "$(IFS=:; echo "${keep[*]}")"; changed=1; fi
  fi
  ((changed)) && log "byobu: new tabs no longer get pyenv/rbenv/old Go settings (open shells: exec zsh -l)"
  return 0
}
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
fix_hypr_signature  # before anything runs hyprpm or hyprctl

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
  # packages.py needs the system python3 + PyYAML (not mise's python) to read packages.yaml, and gpg for apt repo keys
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
  retire_terminator
  return 0
}
# Terminator support was dropped (kitty and Windows Terminal remain): its config link into this repo would dangle.
# Remove it and put back the config it replaced, if there was one.
retire_terminator() {
  local t="$HOME/.config/terminator/config"
  [[ -L $t && $(readlink "$t") == "$DOT/"* ]] || return 0
  command rm -f "$t"
  restore .config/terminator/config
  rmdir "$HOME/.config/terminator" 2>/dev/null || true
  log "Terminator: config link removed (no longer part of these dotfiles)"
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
  linux/trippy/trippy.toml            .config/trippy/trippy.toml
  linux/termscp/theme.toml            .config/termscp/theme.toml
  linux/tealdeer/config.toml          .config/tealdeer/config.toml
  linux/kitty/dotfiles.conf           .config/kitty/dotfiles.conf
  linux/kitty/theme.conf              .config/kitty/theme.conf
  linux/hypr/dotfiles.lua             .config/hypr/dotfiles.lua
  linux/hypr/windows.sh               .config/hypr/dotfiles-windows.sh
  linux/desktop/record.sh             .config/hypr/dotfiles-record.sh
  linux/desktop/record.sh             .local/bin/dotfiles-record
  linux/cosmic/SynthWave-84.ron       .config/cosmic-themes/SynthWave-84.ron
  linux/cosmic/fcitx5.desktop         .config/autostart/dotfiles-fcitx5.desktop
  linux/cosmic/pivot.desktop          .config/autostart/dotfiles-pivot.desktop
  linux/cosmic/blueman.desktop        .config/autostart/blueman.desktop
  linux/hypr/panel.sh                 .config/hypr/dotfiles-panel.sh
  linux/hypr/hyprland-only.conf       .config/systemd/user/hypridle.service.d/dotfiles-hyprland-only.conf
  linux/hypr/hyprland-only.conf       .config/systemd/user/hyprpaper.service.d/dotfiles-hyprland-only.conf
  linux/hypr/hyprland-only.conf       .config/systemd/user/swaync.service.d/dotfiles-hyprland-only.conf
  linux/hypr/swaync-panel.conf        .config/systemd/user/swaync.service.d/dotfiles-panel.conf
  linux/wayle/config.toml             .config/wayle/config.toml
  linux/wayle/styles/index.scss       .config/wayle/styles/index.scss
  linux/hyprshell/config.toml         .config/hyprshell/config.toml
  linux/hyprshell/styles.css          .config/hyprshell/styles.css
  linux/wallust/SynthWave-84.json     .config/wallust/colorschemes/SynthWave-84.json
  linux/ssh/tun                       .local/bin/tun
)
unlink_ours() {  # unlink_ours <path>: remove it if it's a link into this repo
  [[ -L $1 && $(readlink "$1") == "$DOT/"* ]] || return 0
  command rm -f "$1"; log "unlinked ${1/#$HOME/\~}"
}
link_skip() {  # link_skip <link under $HOME>: why this machine doesn't get it (nothing: it does). Also used by --check
  local d=$1
  if [[ $d == .config/kitty/* ]] && ! have kitty; then echo kitty  # kitty: packages.yaml, on a desktop
  elif [[ $d == .config/hypr/* || $d == .config/systemd/user/* ]] && ! have Hyprland; then echo hyprland
  elif [[ $d == .config/hyprshell/* && ! -x $HOME/.local/bin/hyprshell ]]; then echo hyprshell  # built only on GTK 4.18+
  elif [[ $d == .config/wayle/* && ! -x $HOME/.local/bin/wayle ]]; then echo wayle  # packages.yaml, under Hyprland
  elif [[ $d == .config/wallust/* ]] && ! have wallust; then echo wallust  # the Hyprland desktop setup's
  elif [[ $d == .config/cosmic* || $d == .config/autostart/dotfiles-* || $d == .config/autostart/blueman.desktop ||
          $d == .local/bin/dotfiles-record ]] && ! have cosmic-session; then echo cosmic
  fi
  return 0
}
ssh_has_tags() {  # OpenSSH 9.4+ (Tag, Match tagged): older ones reject the whole config over it
  local v; v=$(ssh -V 2>&1 | sed -n 's/^OpenSSH_\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
  [[ -n $v ]] && (( ${v% *} > 9 || (${v% *} == 9 && ${v#* } >= 4) ))
}
link_configs() {
  local i
  for ((i = 0; i < ${#LINKS[@]}; i += 2)); do
    case $(link_skip "${LINKS[i + 1]}") in
      '') link "${LINKS[i]}" "$HOME/${LINKS[i + 1]}" ;;
      # a desktop's links go only with --no-hyprland / --no-cosmic; otherwise they stay as they are
      hyprland) if (( DROP_HYPRLAND )); then unlink_ours "$HOME/${LINKS[i + 1]}"; fi ;;
      cosmic) if (( DROP_COSMIC )); then unlink_ours "$HOME/${LINKS[i + 1]}"; fi ;;
    esac
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

# The repo's pre-commit hook (.githooks/pre-commit): a privacy check before every commit to this public repo.
# Set in the clone's own config (not ~/.gitconfig), so it applies to this repo only.
configure_git_hooks() {
  have git && git -C "$DOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  [[ $(git -C "$DOT" config --local core.hooksPath) == .githooks ]] && return 0
  git -C "$DOT" config --local core.hooksPath .githooks
  log "git: this repo's privacy check runs before each commit (.githooks/pre-commit)"
}
configure_git() {
  configure_git_hooks
  have delta && have git || return 0
  git config --global --fixed-value --unset-all include.path "$DOT/git/delta.gitconfig" 2>/dev/null || true  # pre-3.0 path
  git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/linux/git/delta.gitconfig" && return 0
  git config --global --add include.path "$DOT/linux/git/delta.gitconfig"
  log "git: delta pager"
}

# ~/.ssh/config: the repo's shared defaults (linux/ssh: keepalives; connection reuse for hosts tagged `mux`) included at
# its END, after `Match all` so they apply whatever block the file ends in. ssh keeps the first value it finds for each
# setting, so your own settings, above, win. A missing file in Include is skipped (dotfiles-mux.conf on old OpenSSH).
# The two files are COPIED to ~/.ssh with mode 600, not linked: ssh rejects a config file others can write ("Bad owner
# or permissions") and then refuses every connection, and the repo's files are group-writable under Ubuntu's umask 002.
SSH_CONF="$HOME/.ssh/config"
SSH_MARK="# dotfiles: shared defaults from linux/ssh, last so your settings above win (install.cmd --uninstall removes this)"
SSH_LINES=("Match all" "Include ~/.ssh/dotfiles.conf ~/.ssh/dotfiles-mux.conf")
ssh_copy_ok() {  # ssh_copy_ok <name>: ~/.ssh/<name> is the repo's linux/ssh/<name>, mode 600
  [[ -f $HOME/.ssh/$1 && ! -L $HOME/.ssh/$1 && $(stat -c %a "$HOME/.ssh/$1") == 600 ]] &&
    cmp -s "$DOT/linux/ssh/$1" "$HOME/.ssh/$1"
}
ssh_wanted() {  # the copies this machine gets: the reuse one only on OpenSSH 9.4+
  echo dotfiles.conf; if ssh_has_tags; then echo dotfiles-mux.conf; fi
}
configure_ssh() {
  have ssh || return 0
  [[ -d $HOME/.ssh ]] || mkdir -m 700 "$HOME/.ssh"
  local f changed=0
  for f in $(ssh_wanted); do
    ssh_copy_ok "$f" && continue
    command rm -f "$HOME/.ssh/$f"; install -m 600 "$DOT/linux/ssh/$f" "$HOME/.ssh/$f"; changed=1
  done
  if ! ssh_has_tags && [[ -e $HOME/.ssh/dotfiles-mux.conf ]]; then command rm -f "$HOME/.ssh/dotfiles-mux.conf"; fi
  if ! grep -qxF "$SSH_MARK" "$SSH_CONF" 2>/dev/null; then
    local new=0; [[ -e $SSH_CONF ]] || new=1
    { [[ -s $SSH_CONF ]] && printf '\n'; printf '%s\n' "$SSH_MARK" "${SSH_LINES[@]}"; } >>"$SSH_CONF"
    (( new )) && chmod 600 "$SSH_CONF"
    changed=1
  fi
  (( changed )) && log "ssh: keepalives for every host; connection reuse for hosts you tag (Tag mux); tun for tunnels"
  return 0
}
uninstall_ssh() {
  local f; for f in dotfiles.conf dotfiles-mux.conf; do command rm -f "$HOME/.ssh/$f"; done
  grep -qxF "$SSH_MARK" "$SSH_CONF" 2>/dev/null || return 0
  local rest  # everything but our three lines (the mark and the two after it)
  rest=$(awk -v m="$SSH_MARK" 'skip > 0 { skip--; next } $0 == m { skip = 2; next } { print }' "$SSH_CONF")
  if [[ -z ${rest//[[:space:]]/} ]]; then command rm -f "$SSH_CONF"  # only ours was in it
  else printf '%s\n' "$rest" >| "$SSH_CONF"; fi
  log "ssh: shared defaults removed from ~/.ssh/config"
}

# trippy's map and locations: MaxMind's free GeoLite2 City database, fetched and kept fresh by geoipupdate (it only
# downloads when MaxMind has a newer one). That needs a free MaxMind account: asked once for its account ID and a
# license key, saved for geoipupdate in GEOIP_CONF (readable only by you; per machine, never in the repo). Enter at
# the prompt skips it, remembered in GEOIP_SKIP; delete that file to be asked again.
GEOIP_CONF="$HOME/.config/GeoIP.conf"
GEOIP_DIR="$HOME/.local/share/GeoIP"
GEOIP_SKIP="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/geoip-skipped"
GEOIP_MARK="# dotfiles installer: MaxMind GeoLite2 for trippy (configure_geoip in linux/install.sh)"
configure_geoip() {
  have trip && have geoipupdate || return 0
  if [[ ! -f $GEOIP_CONF ]]; then
    [[ -f $GEOIP_SKIP ]] && return 0
    if ! { : </dev/tty; } 2>/dev/null; then
      warn "GeoIP: no terminal to ask for a MaxMind license key; trip runs without its map (re-run interactively)"
      return 0
    fi
    local id key
    {
      printf '\n  GeoIP for trip'"'"'s map: a free MaxMind account (https://www.maxmind.com/en/geolite2/signup),\n'
      printf '  then Account > Manage license keys > Generate. Enter skips (asked again if you delete %s).\n' \
        "${GEOIP_SKIP/#$HOME/\~}"
    } >/dev/tty
    read -r -p '  MaxMind account ID: ' id </dev/tty
    if [[ -z $id ]]; then
      mkdir -p "$(dirname "$GEOIP_SKIP")"; : >"$GEOIP_SKIP"
      log "GeoIP: skipped; trip runs without its map"
      return 0
    fi
    read -r -s -p '  MaxMind license key: ' key </dev/tty; printf '\n' >/dev/tty
    if [[ ! $id =~ ^[0-9]+$ || -z $key ]]; then warn "GeoIP: the account ID is a number and the key can't be empty; not saved"; return 0; fi
    mkdir -p "$(dirname "$GEOIP_CONF")" "$GEOIP_DIR"
    ( umask 077; printf '%s\nAccountID %s\nLicenseKey %s\nEditionIDs GeoLite2-City\nDatabaseDirectory %s\n' \
        "$GEOIP_MARK" "$id" "$key" "$GEOIP_DIR" >"$GEOIP_CONF" )
    if ! spin "GeoIP: GeoLite2 City" geoipupdate -f "$GEOIP_CONF"; then
      command rm -f "$GEOIP_CONF"  # asked again next run
      warn "GeoIP: download failed; check the account ID and license key (asked again on the next run)"
    fi
    return 0
  fi
  mkdir -p "$GEOIP_DIR"
  spin "GeoIP: GeoLite2 City" geoipupdate -f "$GEOIP_CONF" || warn "GeoIP: update failed; trip keeps the database it has"
}
uninstall_geoip() {
  command rm -f "$GEOIP_SKIP"
  [[ -f $GEOIP_CONF && $(head -n 1 "$GEOIP_CONF") == "$GEOIP_MARK" ]] || return 0
  command rm -f "$GEOIP_CONF" "$GEOIP_DIR/GeoLite2-City.mmdb" "$GEOIP_DIR/.geoipupdate.lock"
  rmdir "$GEOIP_DIR" 2>/dev/null || true
  log "GeoIP: MaxMind key and GeoLite2 database removed"
}

# SuzieQ: ~/.suzieq/suzieq-cfg.yml from linux/suzieq/suzieq-cfg.yml. A copy, not a link: SuzieQ doesn't expand `~`
# in paths, so the template's @HOME@ and @TZ@ (this machine's timezone; SuzieQ shows UTC otherwise) are filled in.
# Rewritten each run while it's ours (first line SUZIEQ_MARK); a config you wrote yourself is left alone. The
# inventory (~/.suzieq/inventory.yml) and the collected data (~/.suzieq/parquet) are yours: never touched.
SUZIEQ_CFG="$HOME/.suzieq/suzieq-cfg.yml"
SUZIEQ_MARK="# dotfiles installer: from linux/suzieq/suzieq-cfg.yml (configure_suzieq in linux/install.sh)"
configure_suzieq() {
  [[ -x $HOME/.local/share/uv/tools/suzieq/bin/sq-poller ]] || return 0
  if [[ -f $SUZIEQ_CFG && $(head -n 1 "$SUZIEQ_CFG") != "$SUZIEQ_MARK" ]]; then
    log "suzieq: ${SUZIEQ_CFG/#$HOME/\~} is your own, left as is"; return 0
  fi
  local tz; tz=$(timedatectl show -p Timezone --value 2>/dev/null) || true
  [[ -n $tz ]] || tz=$(cat /etc/timezone 2>/dev/null) || true
  mkdir -p "$(dirname "$SUZIEQ_CFG")"
  { printf '%s\n' "$SUZIEQ_MARK"
    sed -e "s|@HOME@|$HOME|g" -e "s|@TZ@|${tz:-UTC}|g" "$DOT/linux/suzieq/suzieq-cfg.yml"; } >|"$SUZIEQ_CFG"
  log "suzieq: ${SUZIEQ_CFG/#$HOME/\~} (timezone ${tz:-UTC})"
}
uninstall_suzieq() {
  [[ -f $SUZIEQ_CFG && $(head -n 1 "$SUZIEQ_CFG") == "$SUZIEQ_MARK" ]] || return 0
  command rm -f "$SUZIEQ_CFG"
  rmdir "$(dirname "$SUZIEQ_CFG")" 2>/dev/null || true  # only if no inventory or data is left in it
  log "suzieq: config removed (inventory and data kept)"
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
# fcitx5's input methods for Hyprland and COSMIC: US keyboard and Mozc (fcitx5 alone starts with the keyboard only)
# The desktop setup's Quickshell overview: older versions of this installer set it to one row of 5 workspaces
# (instead of 2 x 5). Hyprspace replaced it, so that edit is undone on install and uninstall
# Waybar's workspace modules: 1 persistent workspace instead of 5, so the bar shows the ones that exist
# (Hyprspace and new windows add them). One "*": 5 line per module in the desktop setup's ModulesWorkspaces.
WAYBAR_WS="$WAYBAR_DIR/ModulesWorkspaces"
# Our wallust colour schemes (linux/wallust, linked into ~/.config/wallust/colorschemes): the desktop setup's
# theme menu (ThemeChanger.sh) and wallpaper script (WallustSwww.sh) only know `wallust theme <built-in>`.
# These edits list our schemes in the menu and apply them with `wallust cs`; built-in themes work as before.
WALLUST_CS_DIR='"${XDG_CONFIG_HOME:-$HOME/.config}"/wallust/colorschemes'
WALLUST_THEME_SCRIPTS=("$HOME/.config/hypr/scripts/WallustSwww.sh" "$HOME/.config/hypr/scripts/ThemeChanger.sh")
WALLUST_LIST_OLD='  wallust "${wallust_args[@]}" theme list \'
WALLUST_LIST_NEW='  { for f in '"$WALLUST_CS_DIR"'/*.json; do [ -e "$f" ] && echo "- $(basename "$f" .json)"; done; wallust "${wallust_args[@]}" theme list; } \'
# `theme -- "$x"` -> `$(... cs or theme) -- "$x"`, for the variable each script uses
wallust_verb() { printf '$([ -f %s/"%s".json ] && echo cs || echo theme)' "$WALLUST_CS_DIR" "$1"; }
swap_text() {  # swap_text <file> <old> <new>: replace that literal text everywhere in the file; 1 if it wasn't there
  grep -qF -- "$2" "$1" 2>/dev/null || return 1
  A=$2 B=$3 perl -i -pe 's/\Q$ENV{A}\E/$ENV{B}/g' "$1"
}
QS_OVERVIEW="$HOME/.config/quickshell/overview/common/Config.qml"
QS_ROWS='            property int rows: 2'
QS_OUR_ROWS='            property int rows: 1  // dotfiles: 5 workspaces (was 2)'
# The desktop setup's waybar opens the wallpaper menu as UserScripts/WallpaperSelect.sh, but ships it in scripts/
# (its bug, as of Hyprland-Dots 2026-11): a link there makes those clicks work. Its updates keep UserScripts.
WALLSEL_LINK="$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"
WALLSEL="$HOME/.config/hypr/scripts/WallpaperSelect.sh"
# The desktop setup starts and restarts waybar through WaybarStartup.sh (login, Refresh.sh, lid, display profiles,
# wallpaper changes). This line after its first makes it do nothing while wayle is the panel (linux/hypr/panel.sh),
# instead of waybar appearing until panel.sh's watcher closes it. Its updates replace the script: re-added each run.
WAYBAR_STARTUP="$HOME/.config/hypr/scripts/WaybarStartup.sh"
WAYBAR_SKIP='[ "$("$HOME/.config/hypr/dotfiles-panel.sh" 2>/dev/null)" = wayle ] && exit 0  # dotfiles: wayle is the panel'
FCITX_PROFILE="$HOME/.config/fcitx5/profile"
# fcitx5's Wayland frontend: keep its virtual keyboard when focus leaves an app. Without it, fcitx5 drops the virtual
# keyboard as the app loses focus, which lets go of the keys it held, Alt too: Alt-Tab's switcher (pivot under COSMIC)
# took Alt as released and flipped windows at once, from any app with Japanese input on (kitty, VS Code, Electron).
FCITX_WAYLANDIM="$HOME/.config/fcitx5/conf/waylandim.conf"
FCITX_WAYLANDIM_TEXT='PersistentVirtualKeyboard=True'
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
  have Hyprland || { (( DROP_HYPRLAND )) && drop_hypr_dropins; return 0; }  # --no-hyprland: the drop-ins' dirs too
  # the hyprland-only.conf drop-ins (LINKS): systemd reads them on a reload
  systemctl --user daemon-reload 2>/dev/null || true
  local v; v=$(hypr_version)
  if [[ -n $v ]] && ! dpkg --compare-versions "$v" ge 0.55 2>/dev/null; then  # Lua config: 0.55+
    warn "Hyprland $v is too old for dotfiles.lua (needs 0.55+, e.g. from ppa:cppiber/hyprland); Hyprland settings skipped"
    return 0
  fi
  [[ -f $HYPR_KEYS ]] || { warn "Hyprland: no ${HYPR_KEYS/#$HOME/\~} (desktop setup not copied yet?); Hyprland settings skipped"; return 0; }
  # the hyprpm plugins (packages.yaml) are only built from inside a running Hyprland
  if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} && -e ${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/desktop-hyprland ]] && have hyprpm &&
     ! hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -A1 'Plugin Hyprspace$' | grep -q 'enabled: true'; then
    log "Hyprland: title bars and overview (hyprpm plugins) come on a run of the installer inside Hyprland"
  fi
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
  if grep -qE '^\s*"\*": 5$' "$WAYBAR_WS" 2>/dev/null; then
    perl -i -pe 's{^(\s*"\*": )5$}{${1}1 // dotfiles: only the workspaces that exist (was 5)}' "$WAYBAR_WS"
    pkill -USR2 -x waybar 2>/dev/null || true
    log "waybar: workspace buttons for the workspaces that exist (was always 5)"
  fi
  local ws_var wallust_changed=''
  for f in "${WALLUST_THEME_SCRIPTS[@]}"; do
    [[ -f $f ]] || continue
    for ws_var in '$global_theme' '${choice}'; do
      swap_text "$f" 'wallust "${wallust_args[@]}" theme -- "'"$ws_var"'"' 'wallust "${wallust_args[@]}" '"$(wallust_verb "$ws_var")"' -- "'"$ws_var"'"' && wallust_changed=1
    done
    swap_text "$f" "$WALLUST_LIST_OLD" "$WALLUST_LIST_NEW" && wallust_changed=1
  done
  if [[ -n $wallust_changed ]]; then
    command rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/wallust_theme_list.txt"  # the menu's cached theme list
    log "wallust: SynthWave-84 in the theme menu (Super-T)"
  fi
  # Hyprspace is the overview now (tap Super): the Quickshell one goes back to how the desktop setup ships it
  if grep -qxF -e "$QS_OUR_ROWS" "$QS_OVERVIEW" 2>/dev/null; then
    A=$QS_OUR_ROWS B=$QS_ROWS perl -i -pe 's/^\Q$ENV{A}\E$/$ENV{B}/' "$QS_OVERVIEW"
    log "Quickshell overview: back to the desktop setup's (Hyprspace replaces it)"
  fi
  if [[ -f $WAYBAR_STARTUP ]] && ! grep -qxF -e "$WAYBAR_SKIP" "$WAYBAR_STARTUP"; then
    insert_after "$WAYBAR_STARTUP" '^#!' "$WAYBAR_SKIP"
    log "waybar: not started while wayle is the panel"
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
  configure_fcitx_profile
}
configure_fcitx_profile() {  # Hyprland and COSMIC
  if have fcitx5 && [[ ! -e $FCITX_PROFILE ]]; then
    mkdir -p "$(dirname "$FCITX_PROFILE")"
    printf '%s\n' "$FCITX_PROFILE_TEXT" >| "$FCITX_PROFILE"
    log "fcitx5: US keyboard + Mozc (Ctrl-Space switches)"
  fi
  if have fcitx5 && [[ ! -e $FCITX_WAYLANDIM ]]; then  # one the user made stays theirs
    mkdir -p "$(dirname "$FCITX_WAYLANDIM")"
    printf '%s\n' "$FCITX_WAYLANDIM_TEXT" >| "$FCITX_WAYLANDIM"
    log "fcitx5: keeps its virtual keyboard across focus changes (Alt-Tab; restart fcitx5 or log in again)"
  fi
}
drop_hypr_dropins() {  # the hyprland-only.conf drop-ins, once unlinked: their empty dirs, and tell systemd
  local u
  for u in hypridle hyprpaper swaync; do rmdir "$HOME/.config/systemd/user/$u.service.d" 2>/dev/null || true; done
  systemctl --user daemon-reload 2>/dev/null || true
}
uninstall_hyprland() {
  drop_hypr_dropins
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
  if drop_line "$WAYBAR_STARTUP" "$WAYBAR_SKIP"; then log "waybar: WaybarStartup.sh as the desktop setup ships it"; fi
  if [[ -f $HOME/.config/hypr/dotfiles-panel ]]; then  # the wayle choice (linux/hypr/panel.sh): waybar again at login
    command rm -f "$HOME/.config/hypr/dotfiles-panel"; log "panel: back to waybar at the next login"
  fi
  if grep -qxF -e "$QS_OUR_ROWS" "$QS_OVERVIEW" 2>/dev/null; then
    A=$QS_OUR_ROWS B=$QS_ROWS perl -i -pe 's/^\Q$ENV{A}\E$/$ENV{B}/' "$QS_OVERVIEW"
    log "overview: back to 10 workspaces"
  fi
  if grep -q '// dotfiles: only the workspaces that exist' "$WAYBAR_WS" 2>/dev/null; then
    perl -i -pe 's{^(\s*"\*": )1 // dotfiles: only the workspaces that exist.*$}{${1}5}' "$WAYBAR_WS"
    pkill -USR2 -x waybar 2>/dev/null || true
    log "waybar: 5 workspace buttons again"
  fi
  local ws_var wallust_changed=''
  for f in "${WALLUST_THEME_SCRIPTS[@]}"; do
    [[ -f $f ]] || continue
    for ws_var in '$global_theme' '${choice}'; do
      swap_text "$f" 'wallust "${wallust_args[@]}" '"$(wallust_verb "$ws_var")"' -- "'"$ws_var"'"' 'wallust "${wallust_args[@]}" theme -- "'"$ws_var"'"' && wallust_changed=1
    done
    swap_text "$f" "$WALLUST_LIST_NEW" "$WALLUST_LIST_OLD" && wallust_changed=1
  done
  if [[ -n $wallust_changed ]]; then
    command rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/wallust_theme_list.txt"
    log "wallust: theme menu and wallpaper script back to built-in themes only"
  fi
  # ours unless changed since: compare without fcitx5's comments and blank lines (it rewrites the file)
  local strip='/^#/d; /^[[:space:]]*$/d'
  if [[ -f $FCITX_WAYLANDIM ]] && [[ $(sed "$strip" "$FCITX_WAYLANDIM") == "$FCITX_WAYLANDIM_TEXT" ]]; then
    command rm -f "$FCITX_WAYLANDIM"; rmdir "$(dirname "$FCITX_WAYLANDIM")" 2>/dev/null || true
    log "fcitx5: Wayland frontend setting removed"
  fi
  if [[ -f $FCITX_PROFILE ]] && [[ $(sed "$strip" "$FCITX_PROFILE") == "$(sed "$strip" <<<"$FCITX_PROFILE_TEXT")" ]]; then
    command rm -f "$FCITX_PROFILE"; rmdir "$(dirname "$FCITX_PROFILE")" 2>/dev/null || true
    log "fcitx5: input-method profile removed"
  fi
}

# VS Code under Hyprland: Electron picks its secret store from XDG_CURRENT_DESKTOP, doesn't know Hyprland,
# wayle's dashboard (menu) button: the distro logo in SynthWave '84 colours. Made from the Simple Icons logo wayle
# installs (wayle icons setup), so no logo file sits in this repo: its single solid fill becomes a diagonal
# yellow -> pink -> cyan gradient. A full-colour icon, so GTK draws it as is (linux/wayle/config.toml: icon-override).
WAYLE_LOGO="$HOME/.local/share/icons/hicolor/scalable/apps/dotfiles-distro-logo.svg"
configure_wayle_logo() {
  [[ -x $HOME/.local/bin/wayle ]] || return 0
  local id src new
  id=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")
  src="$HOME/.local/share/wayle/icons/hicolor/scalable/actions/si-$id-symbolic.svg"
  [[ -n $id && -f $src ]] || { warn "wayle: no $id logo in its icons (wayle icons setup?); menu button logo left as is"; return 0; }
  new=$(perl -0777 -pe '
    s/\s+gpa:fill=\x27[^\x27]*\x27//g;
    s/<svg(?![^>]*xmlns=)/<svg xmlns=\x27http:\/\/www.w3.org\/2000\/svg\x27/;   # GTK draws it as a plain SVG now
    s/fill=\x27rgb\(0,0,0\)\x27/fill=\x27url(#dotfiles-synthwave)\x27/g;
    s{(<svg[^>]*>)}{$1\n  <defs><linearGradient id=\x27dotfiles-synthwave\x27 x1=\x270\x27 y1=\x270\x27 x2=\x271\x27 y2=\x271\x27><stop offset=\x270\x27 stop-color=\x27#fede5d\x27/><stop offset=\x270.5\x27 stop-color=\x27#ff7edb\x27/><stop offset=\x271\x27 stop-color=\x27#36f9f6\x27/></linearGradient></defs>};
  ' "$src")
  [[ $new == *dotfiles-synthwave* ]] || { warn "wayle: the $id logo's format changed; menu button logo left as is"; return 0; }
  [[ -f $WAYLE_LOGO && $(<"$WAYLE_LOGO") == "$new" ]] && return 0
  mkdir -p "$(dirname "$WAYLE_LOGO")"
  printf '%s\n' "$new" >| "$WAYLE_LOGO"
  log "wayle: menu button logo in SynthWave colours"
}

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

# ---------------------------------------------------------------- COSMIC
# COSMIC's settings: one file per key under ~/.config/cosmic. Copied, not linked: COSMIC Settings saves by replacing
# the file, link and all. What we last wrote is kept in $COSMIC_STATE; a file that no longer matches it was changed in
# COSMIC Settings, and is left alone. What was there before the first time goes to the backup dir.
COSMIC_CFG="$HOME/.config/cosmic"
COSMIC_STATE="$HOME/.local/state/dotfiles/cosmic"
COSMIC_KEYS=(  # <key file under ~/.config/cosmic> <value, or @file in this repo; empty: not set on this machine>
  com.system76.CosmicSettings.Shortcuts/v1/custom  @linux/cosmic/shortcuts.ron  # the Hyprland setup's keys
  com.system76.CosmicComp/v1/autotile              true      # tiling, as in Hyprland: on for every workspace
  com.system76.CosmicComp/v1/autotile_behavior     Global
  com.system76.CosmicComp/v1/workspaces            '(workspace_mode: OutputBound, workspace_layout: Horizontal)'
  # The panel (top) and dock: see-through, small, and their applets (linux/cosmic/panel; in the format COSMIC
  # Settings writes, so an unchanged one compares equal). Left: workspaces. Middle: Caffeine, clock, notifications.
  # Right: system monitor and the input method (EN / あ, linux/cosmic/input-applet) first, where wayle has cpu/ram
  # and the input method, then audio, Bluetooth, network, battery, power. An applet that isn't installed is skipped.
  com.system76.CosmicPanel.Panel/v1/plugins_center @linux/cosmic/panel/panel-plugins_center.ron
  com.system76.CosmicPanel.Panel/v1/plugins_wings  @linux/cosmic/panel/panel-plugins_wings.ron
  com.system76.CosmicPanel.Panel/v1/opacity        0.45
  com.system76.CosmicPanel.Panel/v1/size           S
  com.system76.CosmicPanel.Dock/v1/plugins_center  @linux/cosmic/panel/dock-plugins_center.ron
  com.system76.CosmicPanel.Dock/v1/plugins_wings   @linux/cosmic/panel/dock-plugins_wings.ron
  com.system76.CosmicPanel.Dock/v1/opacity         0.45
  com.system76.CosmicPanel.Dock/v1/size            S
  com.system76.CosmicPanel.Dock/v1/border_radius   8
  # The system monitor's right click (and "Process monitor" in its popup): btop in kitty, as Hyprland's panel does
  io.github.leonardo_panseri.cosmic-ext-applet-sysmon/v1/process_monitor '"kitty -e btop"'
  # (No wallpaper: skwd-wall, Super-W, draws it. The Hyprland setup's, set here once, is taken back below.)
)
# A key dropped from COSMIC_KEYS (its copy is still in $COSMIC_STATE): unless it was changed in COSMIC Settings since,
# put back what was there before this installer first set it (or remove it: COSMIC's default), and forget it.
retire_cosmic_keys() {
  local s rel f k keys=" "
  for ((k = 0; k < ${#COSMIC_KEYS[@]}; k += 2)); do keys+="${COSMIC_KEYS[k]} "; done
  [[ -d $COSMIC_STATE ]] || return 0
  while IFS= read -r s; do
    rel=${s#"$COSMIC_STATE"/}
    [[ $rel == theme || $keys == *" $rel "* ]] && continue
    f=$COSMIC_CFG/$rel
    if [[ -f $f && $(<"$f") == "$(<"$s")" ]]; then
      command rm -f "$f"; restore ".config/cosmic/$rel"
      log "COSMIC: ~/.config/cosmic/$rel back to how it was (no longer set by these dotfiles)"
    fi
    command rm -f "$s"
  done < <(find "$COSMIC_STATE" -type f)
  find "$COSMIC_STATE" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
}
cosmic_value() {  # cosmic_value <value or @file>
  if [[ $1 == @* ]]; then cat "$DOT/${1#@}"; else printf '%s' "$1"; fi
}
configure_cosmic() {
  if ! have cosmic-session; then  # its settings go only with --no-cosmic (or --uninstall), not when it's just missing
    if (( DROP_COSMIC )); then uninstall_cosmic
    elif [[ -d $COSMIC_STATE ]]; then warn "COSMIC: not installed (removed some other way?); its settings left as they are"; fi
    return 0
  fi
  local i f s v changed=''
  for ((i = 0; i < ${#COSMIC_KEYS[@]}; i += 2)); do
    f=$COSMIC_CFG/${COSMIC_KEYS[i]} s=$COSMIC_STATE/${COSMIC_KEYS[i]}
    v=$(cosmic_value "${COSMIC_KEYS[i + 1]}")
    [[ -n $v ]] || continue  # empty: not set on this machine
    [[ -L $f && $(readlink "$f") == "$DOT/"* ]] && command rm -f "$f"  # linked by older versions
    if [[ -f $f && $(<"$f") == "$v" ]]; then
      mkdir -p "$(dirname "$s")"; printf '%s' "$v" >| "$s"; continue
    fi
    if [[ -e $f && -f $s ]] && [[ $(<"$f") != "$(<"$s")" ]]; then
      warn "COSMIC: ~/${f#"$HOME"/} was changed in COSMIC Settings; left as it is (delete it and re-run for ours)"
      continue
    fi
    if [[ -e $f && ! -f $s ]]; then backup "$f"; fi  # from before the first install
    mkdir -p "$(dirname "$f")" "$(dirname "$s")"
    printf '%s' "$v" >| "$f"; printf '%s' "$v" >| "$s"
    changed=1
  done
  [[ -n $changed ]] && log "COSMIC: Hyprland's keys, tiling on, workspaces side by side, panel and dock"
  retire_cosmic_keys
  configure_fcitx_profile
  configure_cosmic_theme
}
# The SynthWave '84 theme (linux/cosmic/SynthWave-84.ron), imported when it's new or changed: COSMIC keeps the theme it
# builds from it in ~/.config/cosmic/com.system76.CosmicTheme.Dark*, and tweaks made in Settings stay until then.
# Its importer takes no comments, hence the grep.
COSMIC_THEME_DIRS=(com.system76.CosmicTheme.Dark com.system76.CosmicTheme.Dark.Builder)
configure_cosmic_theme() {
  local src=$DOT/linux/cosmic/SynthWave-84.ron s=$COSMIC_STATE/theme sum tmp d
  have cosmic-settings || return 0
  sum=$(sha256sum "$src" | cut -d' ' -f1)
  [[ -f $s && $(<"$s") == "$sum" ]] && return 0
  if [[ ! -f $s ]]; then  # the first time: keep the theme from before
    for d in "${COSMIC_THEME_DIRS[@]}"; do [[ -e $COSMIC_CFG/$d ]] && backup "$COSMIC_CFG/$d"; done
  fi
  tmp=$(mktemp --suffix=.ron)
  grep -v '^[[:space:]]*//' "$src" >| "$tmp"
  if timeout 60 cosmic-settings appearance import "$tmp" 2>&1 | grep -q '^Successfully imported'; then
    mkdir -p "$COSMIC_STATE"; printf '%s' "$sum" >| "$s"
    log "COSMIC: SynthWave '84 theme, frosted glass"
  else
    warn "COSMIC: the theme import failed; import ~/.config/cosmic-themes/SynthWave-84.ron in Settings > Appearance"
  fi
  command rm -f "$tmp"
  return 0
}
uninstall_cosmic() {  # put back what was there, unless it was changed in COSMIC Settings since
  local i f s rel changed=''
  for ((i = 0; i < ${#COSMIC_KEYS[@]}; i += 2)); do
    rel=.config/cosmic/${COSMIC_KEYS[i]} f=$HOME/$rel s=$COSMIC_STATE/${COSMIC_KEYS[i]}
    [[ -f $s ]] || continue
    if [[ -f $f && $(<"$f") == "$(<"$s")" ]]; then command rm -f "$f"; restore "$rel"; changed=1; fi
    command rm -f "$s"
  done
  if [[ -f $COSMIC_STATE/theme ]]; then  # back to the theme from before (COSMIC's own if there was none)
    local d
    for d in "${COSMIC_THEME_DIRS[@]}"; do command rm -rf "${COSMIC_CFG:?}/$d"; restore ".config/cosmic/$d"; done
    command rm -f "$COSMIC_STATE/theme"; changed=1
  fi
  [[ -d $COSMIC_STATE ]] && find "$COSMIC_STATE" -depth -type d -empty -delete
  [[ -n $changed ]] && log "COSMIC: keys, tiling settings and theme removed"
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
  retire_terminator
  for i in .zlogin .zlogout .zpreztorc .vim; do restore "$i"; done
}

uninstall_system() {
  if have git && [[ $(git -C "$DOT" config --local core.hooksPath 2>/dev/null) == .githooks ]]; then
    git -C "$DOT" config --local --unset core.hooksPath
    log "git: this repo's pre-commit hook turned off"
  fi
  if have git && git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/linux/git/delta.gitconfig"; then
    git config --global --fixed-value --unset-all include.path "$DOT/linux/git/delta.gitconfig"
    log "git: delta pager include removed"
  fi
  local kc; for kc in "${KITTY_CONFS[@]}"; do
    if unkitty "$kc" "$KITTY_INCLUDE" "$KITTY_OLD_INCLUDE" "$KITTY_HYPR_INCLUDE"; then log "kitty: include removed from ${kc/#$HOME/\~}"; fi
  done
  uninstall_ssh
  uninstall_geoip
  uninstall_suzieq
  uninstall_hyprland
  if [[ -f $WAYLE_LOGO ]]; then command rm -f "$WAYLE_LOGO"; log "wayle: menu button logo removed"; fi
  uninstall_gnome_input
  uninstall_cosmic
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

# ---------------------------------------------------------------- check
# --check: compare this machine with the repo and change nothing. Reports links that are missing or point elsewhere,
# packages that would be installed or uninstalled (packages.py --check), COSMIC keys changed in Settings, and git
# settings. Exit 1 when anything differs.
DRIFT=0
drift() { warn "$*"; DRIFT=1; }
check_links() {
  local i d src
  for ((i = 0; i < ${#LINKS[@]}; i += 2)); do
    d=${LINKS[i + 1]} src=$DOT/${LINKS[i]}
    [[ -z $(link_skip "$d") ]] || continue
    if [[ -L $HOME/$d && $(readlink "$HOME/$d") == "$src" ]]; then
      [[ -e $HOME/$d ]] || drift "links: ~/$d points to $src, which is missing"
    elif [[ -L $HOME/$d ]]; then drift "links: ~/$d points to $(readlink "$HOME/$d"), not ${LINKS[i]}"
    elif [[ -e $HOME/$d ]]; then drift "links: ~/$d is a file of its own, not a link to ${LINKS[i]}"
    else drift "links: ~/$d is missing (-> ${LINKS[i]})"; fi
  done
}
check_ssh() {
  have ssh || return 0
  grep -qxF "$SSH_MARK" "$SSH_CONF" 2>/dev/null || drift "ssh: ~/.ssh/config doesn't include the shared defaults (a re-run adds them)"
  local f; for f in $(ssh_wanted); do
    ssh_copy_ok "$f" || drift "ssh: ~/.ssh/$f differs from linux/ssh/$f, or isn't mode 600 (a re-run copies it)"
  done
}
check_cosmic() {
  have cosmic-session || return 0
  local i f s v
  for ((i = 0; i < ${#COSMIC_KEYS[@]}; i += 2)); do
    f=$COSMIC_CFG/${COSMIC_KEYS[i]} s=$COSMIC_STATE/${COSMIC_KEYS[i]}
    v=$(cosmic_value "${COSMIC_KEYS[i + 1]}")
    [[ -n $v && ! ( -f $f && $(<"$f") == "$v" ) ]] || continue
    if [[ -f $f && -f $s && $(<"$f") != "$(<"$s")" ]]; then drift "COSMIC: ${COSMIC_KEYS[i]} was changed in COSMIC Settings"
    else drift "COSMIC: ${COSMIC_KEYS[i]} isn't the repo's (a re-run sets it)"; fi
  done
  have cosmic-settings || return 0  # as configure_cosmic_theme: imported only with it
  local sum; sum=$(sha256sum "$DOT/linux/cosmic/SynthWave-84.ron" | cut -d' ' -f1)
  [[ -f $COSMIC_STATE/theme && $(<"$COSMIC_STATE/theme") == "$sum" ]] || drift "COSMIC: the SynthWave '84 theme isn't imported (a re-run does it)"
}
check_git() {
  have git && git -C "$DOT" rev-parse --git-dir >/dev/null 2>&1 || return 0  # as configure_git_hooks: a clone only
  [[ $(git -C "$DOT" config --local core.hooksPath) == .githooks ]] || drift "git: this repo's pre-commit hook is off (a re-run turns it on)"
  if have delta && ! git config --global --get-all include.path 2>/dev/null | grep -qxF "$DOT/linux/git/delta.gitconfig"; then
    drift "git: the delta pager include is missing from ~/.gitconfig"
  fi
}
check() {
  section links; check_links
  section packages
  if have apt-get && /usr/bin/python3 -c 'import yaml' 2>/dev/null; then
    /usr/bin/python3 -I "$DOT/linux/packages.py" linux --check || DRIFT=1
    if is_wsl && have winget.exe; then /usr/bin/python3 -I "$DOT/linux/packages.py" windows --check || DRIFT=1; fi
  else warn "packages: not on apt or no python3-yaml; not checked"; fi
  section settings; check_git; check_ssh; check_cosmic
  printf '\n'
  if (( DRIFT )); then warn "differs from the repo: a re-run of install.cmd fixes most of it"; return 1; fi
  log "matches the repo"
}

if [[ $CHECK -eq 1 ]]; then check; exit $?; fi
if [[ $UNINSTALL -eq 1 ]]; then uninstall; exit 0; fi
intro
if [[ $PACKAGES -eq 1 ]]; then section packages; install_packages; fi
section configs
fix_tmux_env  # after packages: that's where pyenv, rbenv and /usr/local/go are removed
retire_old_setup
link_configs
section plugins
bootstrap_plugins
section system
patch_windows_terminal
configure_wsl
configure_yasb
configure_git
configure_ssh
configure_geoip
configure_suzieq
configure_kitty
configure_hyprland
configure_wayle_logo
configure_vscode
configure_gnome_input
configure_cosmic
[[ -d $BACKUP ]] && log "backups in $BACKUP"
outro
