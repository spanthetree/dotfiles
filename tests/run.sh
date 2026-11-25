#!/usr/bin/env bash
# tests/run.sh [-i image]... [-v] [scenario]...: installer tests, each scenario in a fresh container (needs docker).
#   default images: ubuntu:24.04 ubuntu:26.04; default scenarios: every tests/scenarios/*.sh; -v: full output
# Exit 1 if any fails. CI runs it too (.github/workflows/checks.yml). Scenarios: see tests/lib.sh for the helpers.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
images=() names=() verbose=0
while (($#)); do
  case $1 in
    -i|--image) images+=("$2"); shift 2 ;;
    -v|--verbose) verbose=1; shift ;;
    -h|--help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) names+=("${1%.sh}"); shift ;;
  esac
done
((${#images[@]})) || images=(ubuntu:24.04 ubuntu:26.04)
if ((${#names[@]} == 0)); then
  for f in tests/scenarios/*.sh; do names+=("$(basename "$f" .sh)"); done
fi
failed=()
for img in "${images[@]}"; do
  for n in "${names[@]}"; do
    [[ -f tests/scenarios/$n.sh ]] || { echo "no such scenario: $n" >&2; exit 2; }
    out=$(mktemp); t0=$SECONDS
    if docker run --rm -v "$PWD:/repo:ro" "$img" bash /repo/tests/lib.sh "$n" >"$out" 2>&1; then
      printf 'ok    %-14s %-18s %3ss\n' "$img" "$n" $((SECONDS - t0))
      ((verbose)) && sed 's/^/    /' "$out"
    else
      printf 'FAIL  %-14s %-18s %3ss\n' "$img" "$n" $((SECONDS - t0))
      if ((verbose)); then sed 's/^/    /' "$out"; else tail -n 40 "$out" | sed 's/^/    /'; fi
      failed+=("$img $n")
    fi
    command rm -f "$out"
  done
done
if ((${#failed[@]})); then printf '\n%s failed:\n' "${#failed[@]}"; printf '  %s\n' "${failed[@]}"; exit 1; fi
echo "all passed"
