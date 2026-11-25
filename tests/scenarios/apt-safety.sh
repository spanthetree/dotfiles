# shellcheck shell=bash  # sourced by tests/lib.sh
# apt removal safety (the rules after the desktop incident): a package only counts as ours when apt has it as
# installed by hand; one other packages still need is never removed (it goes back to apt as a dependency); and
# linux/apt-deps, for packages.yaml's script steps, follows the same rules.
step "a library already here as a dependency is never claimed"
ok "libyaml is a dependency of python3-yaml" apt_has libyaml-0-2
yaml <<'EOF'
linux:
  - libyaml-0-2
EOF
pk
no "not recorded" recorded libyaml-0-2
yaml <<'EOF'
linux: []
EOF
pk --yes
ok "still installed" apt_has libyaml-0-2
ok "python3-yaml untouched" apt_has python3-yaml

step "ours, but something else came to need it: kept, handed back to apt"
yaml <<'EOF'
linux:
  - cowsay
EOF
pk
ok "cowsay recorded" recorded cowsay
apt-get install -y -qq cowsay-off >/dev/null 2>&1   # depends on cowsay: installed by hand, not by the installer
ok "cowsay-off installed" apt_has cowsay-off
yaml <<'EOF'
linux: []
EOF
pk --yes
ok "cowsay kept" apt_has cowsay
ok "cowsay-off kept" apt_has cowsay-off
no "cowsay no longer recorded" recorded cowsay
ok "cowsay now an automatic dependency" eval 'apt-mark showauto | grep -qx cowsay'

step "apt-deps: install only what's missing, remove only what it installed"
apt-get purge -y -qq cowsay-off cowsay >/dev/null 2>&1
linux/apt-deps install curl cowsay
ok "cowsay recorded by apt-deps" grep -qx cowsay "$STATE/apt-deps"
no "curl (already here) not recorded" grep -qx curl "$STATE/apt-deps"
linux/apt-deps remove curl cowsay
no "cowsay removed" apt_has cowsay
ok "curl untouched" apt_has curl

step "apt-deps: kept when something else needs it"
linux/apt-deps install cowsay
apt-get install -y -qq cowsay-off >/dev/null 2>&1
linux/apt-deps remove cowsay
ok "cowsay kept" apt_has cowsay
no "and forgotten" grep -qx cowsay "$STATE/apt-deps"
