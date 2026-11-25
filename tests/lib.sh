#!/usr/bin/env bash
# Runs inside a fresh container (tests/run.sh): bash /repo/tests/lib.sh <scenario>. Copies the repo to /d (scenarios
# swap packages.yaml), sets up the helpers below, then sources tests/scenarios/<scenario>.sh. Any failed check stops it.
#   yaml <<'EOF' ... EOF       packages.yaml (the linux: list etc.) from the heredoc
#   pick <name>...             packages.yaml with just these entries, as they are in the repo's packages.yaml
#   pk [flags]                 run linux/packages.py linux with those flags
#   step <text>                print a heading
#   ok <what> <command...>     the command must succeed
#   no <what> <command...>     the command must fail
#   recorded <name>            the installer recorded it as installed by it (linux.json)
#   apt_has <package>          dpkg has it installed
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive NO_FX=1 HOME=/root PATH=/root/.local/bin:$PATH  # as install.sh does
apt-get update -qq >/dev/null
apt-get install -y -qq sudo python3 python3-yaml curl ca-certificates git procps >/dev/null 2>&1
git config --global --add safe.directory '*'
cp -a /repo /d
cd /d
STATE=$HOME/.local/state/dotfiles

step() { printf '\n== %s\n' "$*"; }
ok() { local what=$1; shift; if "$@"; then echo "  ok: $what"; else echo "  FAILED: $what ($*)"; exit 1; fi; }
no() { local what=$1; shift; if "$@"; then echo "  FAILED: $what (succeeded: $*)"; exit 1; else echo "  ok: $what"; fi; }
pk() { /usr/bin/python3 -I linux/packages.py linux "$@"; }
yaml() { { printf 'settings: {autoremove: true, upgrade: false}\n'; cat; } >| packages.yaml; }
pick() {
  /usr/bin/python3 -I - "$@" <<'PY'
import sys, yaml
want = sys.argv[1:]
full = yaml.safe_load(open('/repo/packages.yaml'))['linux']
name = lambda p: p if isinstance(p, str) else p['name']
found = {name(p): p for p in full if name(p) in want}
missing = [n for n in want if n not in found]
if missing:
    sys.exit(f'pick: not in packages.yaml: {missing}')
yaml.safe_dump({'settings': {'autoremove': True, 'upgrade': False}, 'linux': [found[n] for n in want]},
               open('packages.yaml', 'w'), sort_keys=False)
PY
}
recorded() {
  /usr/bin/python3 -I -c 'import json, sys; sys.exit(0 if sys.argv[1] in json.load(open(sys.argv[2])) else 1)' \
    "$1" "$STATE/linux.json" 2>/dev/null
}
apt_has() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'; }

# shellcheck source=/dev/null
. "/repo/tests/scenarios/$1.sh"
printf '\npassed: %s\n' "$1"
