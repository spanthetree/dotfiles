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

step "--uninstall"
./install.cmd --uninstall --yes --no-fx </dev/null
no "~/.zshrc no longer a link" test -L ~/.zshrc
ok "the user's .zshrc back" grep -qx '# mine' ~/.zshrc
no "hook off" git -C /d config --local core.hooksPath
