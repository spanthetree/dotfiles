# shellcheck shell=bash  # sourced by tests/lib.sh
# shellcheck disable=SC2088  # "~/..." here is text: labels and the installer's messages
# The whole installer with a small package list: links, plugins, the repo's pre-commit hook, --check, --uninstall.
step "install"
yaml <<'EOF'
linux:
  - git
  - curl
EOF
echo '# mine' >| ~/.zshrc   # a file of the user's: backed up, then restored by --uninstall
./install.cmd --no-fx </dev/null
ok "~/.zshrc linked" test "$(readlink ~/.zshrc)" = /d/linux/zsh/zshrc
ok "byobu bin linked" test "$(readlink ~/.config/byobu/bin)" = /d/linux/byobu/bin
ok "the user's .zshrc backed up" eval 'grep -qx "# mine" ~/.dotfiles-backup/*/.zshrc'
ok "pre-commit hook on" test "$(git -C /d config --local core.hooksPath)" = .githooks
no "no desktop links without COSMIC" test -e ~/.config/autostart/dotfiles-pivot.desktop

step "--check: matches"
ok "nothing differs" ./install.cmd --check --no-fx

step "--check: finds drift"
command rm -f ~/.zshenv
echo 'not ours' >| ~/.vimrc.tmp && command rm -f ~/.vimrc && mv ~/.vimrc.tmp ~/.vimrc
git -C /d config --local --unset core.hooksPath
out=$(./install.cmd --check --no-fx 2>&1 || true); echo "$out"
no "exit 1" ./install.cmd --check --no-fx
ok "missing link named" grep -q '~/.zshenv is missing' <<<"$out"
ok "replaced link named" grep -q '~/.vimrc is a file of its own' <<<"$out"
ok "hook named" grep -q 'pre-commit hook is off' <<<"$out"
ok "--check changed nothing" test ! -e ~/.zshenv

step "a re-run fixes it"
./install.cmd --no-fx </dev/null
ok "matches again" ./install.cmd --check --no-fx

step "pyenv, rbenv and old Go leftovers: byobu's server and zsh drop them once the dirs are gone"
apt-get install -y -qq tmux zsh >/dev/null 2>&1
mkdir -p ~/.rbenv   # rbenv kept: its settings stay
env PYENV_ROOT=~/.pyenv PYENV_SHELL=zsh RBENV_ROOT=~/.rbenv PATH=~/.pyenv/shims:~/.rbenv/shims:/usr/local/go/bin:$PATH \
  tmux new -d -s stale
./install.cmd --no-fx </dev/null
tenv=$(tmux show-environment -g)
no "tmux: PYENV_ vars gone" grep -q '^PYENV_' <<<"$tenv"
ok "tmux: RBENV_ROOT kept" grep -q '^RBENV_ROOT=' <<<"$tenv"
no "tmux: pyenv and Go dropped from PATH" grep -qE '^PATH=.*(\.pyenv|/usr/local/go)' <<<"$tenv"
ok "tmux: rbenv and the rest kept" grep -qE '^PATH=.*\.rbenv/shims.*/usr/bin' <<<"$tenv"
tmux kill-server
zout=$(env PYENV_SHELL=zsh PATH=~/.pyenv/shims:/usr/local/go/bin:$PATH __MISE_ORIG_PATH=~/.pyenv/bin:/usr/bin \
  zsh -c 'echo "${PYENV_SHELL-unset} $PATH $__MISE_ORIG_PATH"')
echo "$zout"
ok "zsh: drops PYENV_ vars and pyenv/Go entries, also in mise's PATH" eval '! grep -qE "pyenv|local/go|^zsh" <<<"$zout"'
ok "zsh: keeps the rest" grep -q ' /usr/bin$' <<<"$zout"
command rm -rf ~/.rbenv

step "--uninstall"
./install.cmd --uninstall --yes --no-fx </dev/null
no "~/.zshrc no longer a link" test -L ~/.zshrc
ok "the user's .zshrc back" grep -qx '# mine' ~/.zshrc
no "hook off" git -C /d config --local core.hooksPath
