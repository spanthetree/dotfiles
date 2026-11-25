# shellcheck shell=bash  # sourced by tests/lib.sh
# `private:` entries (Beeper): installed silently on a clean machine; on one with file-reading or screen-recording
# software, asked first (default no), the answer kept until the findings change. Fake agents: their install folders.
export XDG_CURRENT_DESKTOP=test   # a desktop, as Beeper's entry wants
apt-get install -y -qq bsdutils >/dev/null 2>&1   # script(1): a terminal to answer in
yaml <<'EOF'
linux:
  - name: chatapp
    when: desktop
    private: Chatapp keeps your chats decrypted in a local database and shows them on screen
    skip_if: test -e ~/chatapp
    script: touch ~/chatapp
    uninstall: rm -f ~/chatapp
EOF
answer() { script -qec "/usr/bin/python3 -I linux/packages.py linux" /dev/null <<<"$1" | tr -d '\r'; }
answers() { cat "$STATE/private.json" 2>/dev/null || echo '{}'; }

step "clean machine: installed, nothing asked"
ok "monitoring-check finds nothing" test -z "$(linux/monitoring-check)"
pk
ok "installed" test -e ~/chatapp
pk --purge --yes

step "CrowdStrike: no terminal, or --yes, means no"
mkdir -p /opt/CrowdStrike
ok "found" grep -q 'CrowdStrike Falcon' <<<"$(linux/monitoring-check)"
pk </dev/null
no "not installed without a terminal" test -e ~/chatapp
pk --yes
no "not installed with --yes" test -e ~/chatapp

step "asked: no, then remembered"
answer n
no "not installed" test -e ~/chatapp
ok "answer kept" grep -q '"install": false' <<<"$(answers)"
out=$(pk </dev/null 2>&1); echo "$out"
ok "not asked again" grep -q 'as you chose' <<<"$out"

step "findings change: asked again; yes installs"
mkdir -p /opt/Hubstaff
answer y
ok "installed" test -e ~/chatapp
ok "answer kept" grep -q '"install": true' <<<"$(answers)"

step "installed, and a new agent appears: a warning, once"
mkdir -p /opt/sentinelone
out=$(pk </dev/null 2>&1); echo "$out"
ok "warned" grep -q 'is installed, and this machine now shows' <<<"$out"
out=$(pk </dev/null 2>&1)
no "only once" grep -q 'now shows' <<<"$out"

step "--purge forgets the answers"
pk --purge --yes
no "answers gone" test -e "$STATE/private.json"

step "the check itself failing counts as unknown: asked, not installed silently"
command rm -rf /opt/CrowdStrike /opt/Hubstaff /opt/sentinelone
pk --purge --yes
printf '#!/bin/sh\necho boom >&2\nexit 3\n' >| linux/monitoring-check
out=$(pk </dev/null 2>&1); echo "$out"
no "not installed" test -e ~/chatapp
ok "says the check failed" grep -q 'the check itself failed (boom)' <<<"$out"
