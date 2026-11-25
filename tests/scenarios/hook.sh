# shellcheck shell=bash  # sourced by tests/lib.sh
# The repo's pre-commit hook (.githooks/pre-commit): blocks personal patterns, emails and secrets; lets the rest
# through. The test data is put together at run time, so this file trips neither the hook nor gitleaks.
step "gitleaks, as packages.yaml installs it"
mkdir -p ~/.local/bin
pick gitleaks
pk
ok "gitleaks installed" command -v gitleaks

cd /d || exit 1
git config --local core.hooksPath .githooks
git config user.name test && git config user.email "test@users.noreply.github.com"
try() { git add -A && git commit -q -m test; }   # try: commit what's staged
reset() { git reset -q --hard HEAD; }
git add -A && git commit -q --no-verify -m baseline   # the copy may carry uncommitted work: start from a clean tree

step "a clean change goes through"
echo "plain line" >> docs/faq.md
ok "committed" try

step "an email is stopped"
echo "contact: someone@""corp.test" >> docs/faq.md
no "blocked" try; reset
echo "Commits use spanthetree <spanthetree@users.noreply.github.com>" >> docs/faq.md
ok "noreply addresses pass" try

step "your own patterns are stopped"
mkdir -p ~/.config/dotfiles
printf '# my things\nmegacorp\\.internal\nbuild-host-[0-9]+\n' >| ~/.config/dotfiles/private-patterns
echo "ssh build-host-42" >> docs/faq.md
no "blocked (hostname pattern)" try; reset
echo "see wiki.MegaCorp.internal" >> docs/faq.md
no "blocked (case-insensitive)" try; reset

step "a secret is stopped (gitleaks)"
tok=ghp_$(head -c 400 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 36)
echo "token = \"$tok\"" >> docs/faq.md
no "blocked" try; reset

step "--no-verify still works (for a checked false alarm)"
echo "contact: someone@""corp.test" >> docs/faq.md
git add -A
ok "committed with --no-verify" git commit -q --no-verify -m test
