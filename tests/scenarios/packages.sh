# shellcheck shell=bash  # sourced by tests/lib.sh
# Package lifecycle: apt, GitHub release (bare binary and tarball), script entry, tools: under uv.
# Install, re-run, --check, drop one, --purge.
step "install"
yaml <<'EOF'
linux:
  - cowsay
  - name: kind
    github: kubernetes-sigs/kind
    asset: kind-linux-{arch}
  - name: stern
    github: stern/stern
    asset: stern_{version}_linux_{arch}.tar.gz
  - name: hello-script
    skip_if: test -x ~/.local/bin/hello-script
    script: printf '#!/bin/sh\necho hi\n' > ~/.local/bin/hello-script && chmod +x ~/.local/bin/hello-script
    uninstall: rm -f ~/.local/bin/hello-script
  - name: uv
    script: curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
    uninstall: rm -f ~/.local/bin/uv ~/.local/bin/uvx
    tools:
      - httpstat
EOF
mkdir -p ~/.local/bin
pk
ok "cowsay installed and recorded" eval 'apt_has cowsay && recorded cowsay'
ok "kind binary" test -x ~/.local/bin/kind
ok "stern binary" test -x ~/.local/bin/stern
ok "script entry" test -x ~/.local/bin/hello-script
ok "uv tool recorded" recorded uv:httpstat
ok "--check: nothing to do" pk --check

step "--check skips a package this release doesn't have (a run skips it too)"
/usr/bin/python3 -I -c "import yaml; d = yaml.safe_load(open('packages.yaml')); d['linux'].append('no-such-package-dotfiles'); yaml.safe_dump(d, open('packages.yaml', 'w'), sort_keys=False)"
ok "--check still passes" pk --check
sed -i '/no-such-package-dotfiles/d' packages.yaml

step "re-run changes nothing"
cp "$STATE/linux.json" /tmp/before.json
pk
ok "same record" cmp -s /tmp/before.json "$STATE/linux.json"

step "drop cowsay and the uv tool"
/usr/bin/python3 -I - <<'PY'
import yaml
d = yaml.safe_load(open('packages.yaml'))
d['linux'] = [p for p in d['linux'] if p != 'cowsay']
for p in d['linux']:
    if isinstance(p, dict) and p['name'] == 'uv':
        del p['tools']
yaml.safe_dump(d, open('packages.yaml', 'w'), sort_keys=False)
PY
out=$(pk --check 2>&1 || true); echo "$out"
ok "--check names cowsay" grep -q 'would be uninstalled.*cowsay' <<<"$out"
no "--check fails" pk --check
pk --yes
no "cowsay removed" apt_has cowsay
no "httpstat removed" test -x ~/.local/bin/httpstat
no "cowsay no longer recorded" recorded cowsay

step "--purge"
pk --purge --yes
ok "record empty" /usr/bin/python3 -I -c "import json, sys; sys.exit(len(json.load(open('$STATE/linux.json'))))"
no "kind gone" test -e ~/.local/bin/kind
no "script entry gone" test -e ~/.local/bin/hello-script
