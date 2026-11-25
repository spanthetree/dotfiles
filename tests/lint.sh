#!/usr/bin/env bash
# tests/lint.sh: the quick checks (seconds, no containers): syntax of every script, shellcheck, packages.yaml, the
# Windows Terminal merge test, PowerShell parsing (when pwsh is there). CI runs it; run it before committing too.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fail=0
check() { local what=$1; shift; if out=$("$@" 2>&1); then echo "ok    $what"; else echo "FAIL  $what"; sed 's/^/    /' <<<"$out"; fail=1; fi; }
mapfile -t sh < <(git ls-files -co --exclude-standard | grep -E '\.sh$|^linux/(apt-deps|monitoring-check)$|^linux/byobu/bin/|^\.githooks/|^tests/')
mapfile -t py < <(git ls-files -co --exclude-standard '*.py')
mapfile -t ps < <(git ls-files -co --exclude-standard '*.ps1')

check "bash syntax" bash -c 'for f; do bash -n "$f" || exit 1; done' _ "${sh[@]}"
# install.cmd: sh reads only its first line (exec), cmd.exe skips it (:;); it must stay LF-only
check "install.cmd: :; first, LF only, sh runs install.sh" bash -c 'head -c2 install.cmd | grep -q "^:;" &&
  ! grep -q $'"'\\r'"' install.cmd && head -1 install.cmd | sh -n && sh install.cmd --help | grep -q -- --uninstall'
if command -v shellcheck >/dev/null; then check "shellcheck (warnings)" shellcheck -S warning -x "${sh[@]}"
else echo "skip  shellcheck (not installed)"; fi
if command -v zsh >/dev/null; then check "zsh syntax" zsh -n linux/zsh/zshrc linux/zsh/zshenv linux/zsh/zprofile linux/zsh/zsh_aliases
else echo "skip  zsh syntax (no zsh)"; fi
check "python syntax" /usr/bin/python3 -I -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' "${py[@]}"
check "packages.yaml loads" /usr/bin/python3 -I -c 'import yaml; d = yaml.safe_load(open("packages.yaml")); assert d["linux"] and d["windows"]'
check "Windows Terminal merge" /usr/bin/python3 -I windows/terminal/test_merge.py
# packages.yaml: block style only. Windows' parser (powershell-yaml) misreads an inline {...} entry whose quoted
# value has braces in it (`${VAR:-x}`), so a native Windows install couldn't read the file
check "packages.yaml: no inline {...} entries" bash -c '! grep -nE "^[[:space:]]*- \{" packages.yaml'
if command -v pwsh >/dev/null; then
  pscheck=$(mktemp --suffix=.ps1)
  cat >"$pscheck" <<'PS'
$bad = 0
foreach ($f in $args) {
  $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$e)
  if ($e) { $e | ForEach-Object { "${f}: $_" }; $bad = 1 }
}
exit $bad
PS
  check "PowerShell syntax" pwsh -NoProfile -File "$pscheck" "${ps[@]}"
  command rm -f "$pscheck"
else echo "skip  PowerShell syntax (no pwsh)"; fi
exit $fail
