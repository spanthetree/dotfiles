#!/usr/bin/env bash
# Install dotfiles by symlinking into $HOME. Safe to re-run.
#   ./install.sh             link configs, bootstrap antidote + vim-plug, patch Windows Terminal (WSL)
#   ./install.sh --packages  also install missing tools (Debian/Ubuntu only)
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
PACKAGES=0
for arg in "$@"; do
  case $arg in
    --packages) PACKAGES=1 ;;
    -h|--help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;;
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
apt_install() {
  local sudo=() want=() pkg
  [[ $EUID -ne 0 ]] && sudo=(sudo)
  "${sudo[@]}" apt-get update -qq
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then want+=("$pkg"); else warn "apt: $pkg not available here, skipping"; fi
  done
  DEBIAN_FRONTEND=noninteractive "${sudo[@]}" apt-get install -y -qq "${want[@]}"
}

install_packages() {
  if ! have apt-get; then
    warn "--packages supports Debian/Ubuntu only. Missing tools on this machine:"
    local t
    for t in zsh byobu tmux vim gpg rg starship zoxide eza bat fd pyenv uv kubectl helm terraform jq docker ansible xh claude codex opencode; do
      have "$t" || warn "  $t"
    done
    return 0
  fi
  local sudo=()
  [[ $EUID -ne 0 ]] && sudo=(sudo)
  local arch; arch=$(dpkg --print-architecture)

  # HashiCorp rotates its apt key (last 2026-09); refresh it every run so apt-get update keeps verifying
  if [[ -f /etc/apt/sources.list.d/hashicorp.list ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | "${sudo[@]}" gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  fi
  log "apt packages"
  apt_install git curl ca-certificates gnupg openssl unzip xclip \
    zsh byobu tmux vim gpg ripgrep zoxide eza bat fd-find fzf virtualenvwrapper python3 \
    jq yq httpie cloc tcptraceroute whois bgpq4 socat ansible \
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

  if ! have starship; then
    log "starship"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null
  fi
  if ! have uv; then
    log "uv"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
  fi
  if [[ ! -d $HOME/.pyenv ]]; then
    log "pyenv"
    git clone -q https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
  else
    git -C "$HOME/.pyenv" pull -q --ff-only || warn "pyenv update failed; new Python versions may be missing"
  fi
  # Pythons: latest patch of each; 3.12 becomes global unless you already picked one
  local pyenv=$HOME/.pyenv/bin/pyenv v
  export PYENV_ROOT=$HOME/.pyenv
  for v in 3.11 3.12 3.14; do
    v=$("$pyenv" latest -k "$v")
    [[ -d $HOME/.pyenv/versions/$v ]] || { log "python $v (builds from source, a few minutes)"; "$pyenv" install -s "$v"; }
  done
  if [[ $("$pyenv" global) == system ]]; then
    "$pyenv" global "$("$pyenv" latest 3.12)"
  fi
  if [[ ! -d $HOME/.nvm ]]; then
    log "nvm"
    git clone -q https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
    git -C "$HOME/.nvm" -c advice.detachedHead=false checkout -q \
      "$(git -C "$HOME/.nvm" describe --abbrev=0 --tags --match 'v[0-9]*' "$(git -C "$HOME/.nvm" rev-list --tags --max-count=1)")"
  fi
  if ! have kubectl; then
    log "kubectl"
    curl -fsSLo "$HOME/.local/bin/kubectl" \
      "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$arch/kubectl"
    chmod +x "$HOME/.local/bin/kubectl"
  fi
  if ! have helm; then
    log "helm"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 |
      HELM_INSTALL_DIR="$HOME/.local/bin" USE_SUDO=false bash >/dev/null
  fi
  if ! have terraform; then
    log "terraform"
    local codename; codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    curl -fsSL https://apt.releases.hashicorp.com/gpg | "${sudo[@]}" gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$arch signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" |
      "${sudo[@]}" tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    apt_install terraform
  fi

  # Ubuntu's Docker; skipped when Docker CE/Desktop already provides it (packages conflict)
  have docker || { log "docker"; apt_install docker.io docker-compose-v2 docker-buildx; }

  # xh (HTTP client), also as `ht`; GitHub release, no apt package on Ubuntu 24.04
  local m; m=$(uname -m)
  if ! have xh; then
    log "xh"
    local xv; xv=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/ducaale/xh/releases/latest); xv=${xv##*/}
    curl -fsSL "https://github.com/ducaale/xh/releases/download/$xv/xh-$xv-$m-unknown-linux-musl.tar.gz" |
      tar xz -C "$HOME/.local/bin" --strip-components=1 "xh-$xv-$m-unknown-linux-musl/xh"
  fi
  [[ -e $HOME/.local/bin/ht ]] || ln -s xh "$HOME/.local/bin/ht"
  if ! have codex; then
    log "codex"
    curl -fsSL "https://github.com/openai/codex/releases/latest/download/codex-$m-unknown-linux-musl.tar.gz" |
      tar xz -O > "$HOME/.local/bin/codex"
    chmod +x "$HOME/.local/bin/codex"
  fi
  if ! have claude; then
    log "claude code"
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null
  fi
  if ! have opencode; then
    log "opencode"
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path >/dev/null
  fi

  # Docker without sudo (takes effect at next login)
  if have docker && ! id -nG "$USER" | grep -qw docker; then
    log "adding $USER to docker group"
    "${sudo[@]}" usermod -aG docker "$USER"
  fi

  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    log "default shell -> zsh"
    "${sudo[@]}" chsh -s "$(command -v zsh)" "$USER"
  fi

  if is_wsl && have winget.exe; then
    if ! ls /mnt/c/Windows/Fonts /mnt/c/Users/*/AppData/Local/Microsoft/Windows/Fonts 2>/dev/null | grep -qi '^JetBrainsMonoNerdFont'; then
      log "JetBrainsMono Nerd Font (Windows)"
      (cd /mnt/c && winget.exe install -e --id DEVCOM.JetBrainsMonoNerdFont \
        --accept-source-agreements --accept-package-agreements) || warn "font install failed; install JetBrainsMono Nerd Font by hand"
    fi
  fi

  # GUI apps: on the Windows host under WSL (WSL has no GUI); VS Code on Linux only with a desktop session.
  # VS Code settings and extensions come from VS Code Settings Sync after sign-in.
  if is_wsl; then
    local id
    for id in Microsoft.VisualStudioCode Anthropic.Claude Anomaly.OpenCode.Desktop; do
      if have winget.exe && ! (cd /mnt/c && winget.exe list -e --id "$id" >/dev/null 2>&1); then
        log "$id (Windows)"
        (cd /mnt/c && winget.exe install -e --id "$id" \
          --accept-source-agreements --accept-package-agreements) || warn "$id install failed; install it by hand"
      fi
    done
  elif [[ -n ${XDG_CURRENT_DESKTOP:-}${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] && ! have code; then
    log "VS Code"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | "${sudo[@]}" gpg --dearmor --yes -o /usr/share/keyrings/microsoft-vscode.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-vscode.gpg] https://packages.microsoft.com/repos/code stable main" |
      "${sudo[@]}" tee /etc/apt/sources.list.d/vscode.list >/dev/null
    apt_install code
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

[[ $PACKAGES -eq 1 ]] && install_packages
retire_old_setup
link_configs
bootstrap_plugins
patch_windows_terminal
[[ -d $BACKUP ]] && log "backups in $BACKUP"
log "done. Start a new terminal (or: exec zsh -l)"
