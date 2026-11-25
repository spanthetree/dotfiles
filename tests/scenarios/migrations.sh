# shellcheck shell=bash  # sourced by tests/lib.sh
# Record migrations for existing machines: tools moved between entries (pyenv's uv tools now under uv), and an entry
# whose install method changed under the same name (go: /usr/local/go -> mise) offers to uninstall the old install.
step "a machine as it was before: httpstat under pyenv, Go in /usr/local/go"
yaml <<'EOF'
linux:
  - name: uv
    script: curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
    uninstall: rm -f ~/.local/bin/uv ~/.local/bin/uvx
    tools:
      - httpstat
EOF
mkdir -p ~/.local/bin
pk
mkdir -p /usr/local/go/bin && touch /usr/local/go/bin/go
/usr/bin/python3 -I - "$STATE/linux.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
r['pyenv:httpstat'] = r.pop('uv:httpstat')   # recorded under the old entry
r['go'] = {'kind': 'script', 'uninstall': 'sudo rm -rf /usr/local/go'}
json.dump(r, open(sys.argv[1], 'w'))
PY

step "the new layout"
yaml <<'EOF'
linux:
  - name: uv
    script: curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
    uninstall: rm -f ~/.local/bin/uv ~/.local/bin/uvx
    tools:
      - httpstat
  - name: go
    skip_if: test -e ~/new-go
    script: touch ~/new-go
    uninstall: rm -f ~/new-go
EOF
pk --yes
ok "httpstat now recorded under uv" recorded uv:httpstat
no "not under pyenv" recorded pyenv:httpstat
ok "httpstat still installed" test -x ~/.local/bin/httpstat
no "old /usr/local/go uninstalled" test -e /usr/local/go
no "its old record gone" recorded 'go (/usr/local/go)'
ok "new go installed and recorded" eval 'test -e ~/new-go && recorded go'

step "pyenv: kept until its replacement is installed, then offered on its own"
mkdir -p ~/.pyenv/versions/3.6.2
/usr/bin/python3 -I - "$STATE/linux.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
r['pyenv'] = {'kind': 'script', 'uninstall': 'rm -rf ~/.pyenv'}
r['pyenv:httpstat'] = {'kind': 'tool', 'uninstall': 'false', 'check': 'true'}   # both old and new names recorded
json.dump(r, open(sys.argv[1], 'w'))
PY
yaml <<'EOF2'
linux:
  - name: uv
    script: curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
    uninstall: rm -f ~/.local/bin/uv ~/.local/bin/uvx
    tools:
      - httpstat
  - name: python
    skip_if: test -e ~/new-python
    script: exit 1
    uninstall: rm -f ~/new-python
EOF2
out=$(pk --yes 2>&1 || true); echo "$out"
ok "pyenv kept while python failed to install" test -d ~/.pyenv
ok "said why" grep -q 'kept until its replacement (python)' <<<"$out"
ok "old tool name dropped, not uninstalled" eval '! recorded pyenv:httpstat && test -x ~/.local/bin/httpstat'
sed -i 's/    script: exit 1/    script: touch ~\/new-python/' packages.yaml
apt-get install -y -qq bsdutils >/dev/null 2>&1
script -qec "/usr/bin/python3 -I linux/packages.py linux" /dev/null <<<'n' | tr -d '\r' | tee /tmp/out
ok "asked on its own" grep -q 'Replaced installs' /tmp/out
ok "no: pyenv kept" test -d ~/.pyenv
no "and no longer managed" recorded pyenv

step "a uv tool whose Python is gone is reinstalled"
py=$(~/.local/bin/uv tool dir)/httpstat/bin/python
command rm -f "$py" && ln -s /nonexistent/python3 "$py"
pk
ok "httpstat's Python runs again" "$py" -c ''
