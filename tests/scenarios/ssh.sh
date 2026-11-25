# shellcheck shell=bash  # sourced by tests/lib.sh
# SSH: the shared defaults included at the end of ~/.ssh/config (your own settings win), connection reuse only for
# hosts tagged `mux`, tun's self-rebuilding tunnels, and --uninstall taking out only our lines. Against a real sshd.
step "an sshd to talk to, and a config of the user's own"
apt-get install -y -qq openssh-server openssh-client autossh >/dev/null 2>&1
mkdir -p /run/sshd ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
/usr/sbin/sshd
printf 'Host custom\n  HostName 127.0.0.1\n  ServerAliveInterval 7\n' >| ~/.ssh/config
yaml <<'EOF'
linux:
  - git
  - curl
EOF
./install.cmd --no-fx </dev/null
opt() { ssh -G "$1" | awk -v k="$2" '$1 == k {print $2}'; }

step "keepalives everywhere; your own settings win"
ok "include block last" eval 'tail -2 ~/.ssh/config | head -1 | grep -qx "Match all"'
ok "keepalive 30s for any host" test "$(opt localhost serveraliveinterval)" = 30
ok "your Host block's 7s wins" test "$(opt custom serveraliveinterval)" = 7
ok "the repo's file is group-writable here (umask 002, as on Ubuntu)" eval '[[ $(stat -c %a linux/ssh/dotfiles.conf) == 664 ]] || chmod 664 linux/ssh/dotfiles.conf'
ok "copies, mode 600" eval '[[ $(stat -c %a ~/.ssh/dotfiles.conf) == 600 && ! -L ~/.ssh/dotfiles.conf && $(stat -c %a ~/.ssh/dotfiles-mux.conf) == 600 ]]'
ok "tun linked" test -x ~/.local/bin/tun
ok "--check: matches" ./install.cmd --check --no-fx

step "connection reuse only where tagged"
ok "off by default" test "$(opt localhost controlmaster)" = false
{ printf 'Host localhost\n  Tag mux\n'; cat ~/.ssh/config; } >| /tmp/c && mv /tmp/c ~/.ssh/config
ok "on for a tagged host" test "$(opt localhost controlmaster)" = auto
ok "still off for others" test "$(opt custom controlmaster)" = false
command rm -f ~/.ssh/dotfiles-mux.conf
ok "a missing reuse file is skipped (old OpenSSH)" test "$(opt localhost serveraliveinterval)" = 30
./install.cmd --no-fx </dev/null >/dev/null

step "tun: a tunnel that rebuilds itself (to a host tagged mux, too: tun never shares a connection)"
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
wait_port() { local _; for _ in $(seq 40); do port_open "$1" && return 0; sleep 0.5; done; return 1; }
export AUTOSSH_GATETIME=0   # the test kills the link at once; tun's default gives up when the first one dies in 30s
~/.local/bin/tun localhost -L 15022:localhost:22 -o StrictHostKeyChecking=accept-new &
tun_pid=$!
ok "tunnel up" wait_port 15022
first=$(pgrep -f '^/usr/bin/ssh .*15022' | head -1)
pkill -f '^sshd(-session)?: root' || true   # drop the connection on the server side
sleep 2
ok "rebuilt" wait_port 15022
ok "by a new ssh" test "$(pgrep -f '^/usr/bin/ssh .*15022' | head -1)" != "$first"
kill "$tun_pid"; wait "$tun_pid" 2>/dev/null || true
unset AUTOSSH_GATETIME

step "tun: a port that's taken fails at once (on the address asked for: ssh fails only when no address can bind)"
python3 -m http.server 15023 --bind 127.0.0.1 >/dev/null 2>&1 &
web=$!; wait_port 15023
SECONDS=0
no "exits with an error" timeout 30 ~/.local/bin/tun localhost -L 127.0.0.1:15023:localhost:22 -o StrictHostKeyChecking=accept-new
ok "within seconds" test "$SECONDS" -lt 15
kill "$web"

step "--uninstall: only our lines go"
./install.cmd --uninstall --yes --no-fx </dev/null
no "our block gone" grep -q 'dotfiles: shared defaults' ~/.ssh/config
ok "the user's own config kept" grep -qx 'Host custom' ~/.ssh/config
no "copies gone" test -e ~/.ssh/dotfiles.conf
no "tun gone" test -e ~/.local/bin/tun
