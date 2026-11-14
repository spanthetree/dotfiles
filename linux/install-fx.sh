# shellcheck shell=bash
# linux/install.sh look, SynthWave '84: gradient title and section headers, spinners on quiet steps.
# Off when stdout isn't a terminal, with --no-fx, or NO_FX=1 (plain text, step output shown as it runs).
FX=1
[[ -t 1 && -z ${NO_FX:-} && ${TERM:-dumb} != dumb ]] || FX=0
(( FX )) || export NO_FX=1  # packages.py follows suit
FX_COLS=$(tput cols 2>/dev/null || echo 80)
PINK=(255 126 219) PURP=(184 147 206) CYAN=(54 249 246)
RST=$'\033[0m' DIM=$'\033[38;2;169;155;189m'
if (( FX )); then trap 'printf "\033[?25h"' EXIT; fi  # cursor back even on Ctrl-C mid-spin

# grad <text> [from] [to]: text in a color gradient (default pink to cyan)
grad() {
  local s=$1 n=${#1} i k c out='' a b
  read -ra a <<<"${2:-${PINK[*]}}"; read -ra b <<<"${3:-${CYAN[*]}}"
  k=$(( n > 1 ? n - 1 : 1 ))
  for ((i = 0; i < n; i++)); do
    printf -v c '\033[38;2;%d;%d;%dm' $(( a[0] + (b[0] - a[0]) * i / k )) $(( a[1] + (b[1] - a[1]) * i / k )) $(( a[2] + (b[2] - a[2]) * i / k ))
    out+=$c${s:i:1}
  done
  printf '%s%s' "$out" "$RST"
}

# typed <text>: types a gradient line out
typed() {
  local s
  if (( ! FX )); then printf '%s\n' "$1"; return 0; fi
  s=$(grad "$1")
  while [[ -n $s ]]; do  # one escape + one character per step
    if [[ $s == $'\033'* ]]; then printf '%s' "${s%%m*}m"; s=${s#*m}; else printf '%s' "${s:0:1}"; s=${s:1}; sleep 0.008; fi
  done
  printf '\n'
}

# section <name>: ── ✦ name ───── header
section() {
  local w=$(( FX_COLS < 64 ? FX_COLS : 64 )) s="── ✦ $1 "
  while (( ${#s} < w )); do s+='─'; done
  if (( FX )); then printf '\n%s\n' "$(grad "$s" "${PURP[*]}" "${PINK[*]}")"; else printf '\n== %s\n' "$1"; fi
}

# spin <label> <cmd...>: run it with a spinner and the elapsed time, then ✓ or ✗; output shown only if it fails
spin() {
  local label=$1 out pid rc=0 i=0 t0=$SECONDS f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'; shift
  if (( ! FX )); then log "$label"; "$@" </dev/null; return; fi
  out=$(mktemp)
  "$@" >"$out" 2>&1 </dev/null & pid=$!
  printf '\033[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r\033[2K  \033[38;2;255;126;219m%s%s %s %s%ds%s' "${f:i++ % 10:1}" "$RST" "$label" "$DIM" $(( SECONDS - t0 )) "$RST"
    sleep 0.08
  done
  wait "$pid" || rc=$?
  if (( rc == 0 )); then printf '\r\033[2K  \033[38;2;54;249;246m✓%s %s' "$RST" "$label"
  else printf '\r\033[2K  \033[38;2;254;222;93m✗%s %s' "$RST" "$label"; fi
  if (( SECONDS - t0 )); then printf ' %s%ds%s' "$DIM" $(( SECONDS - t0 )) "$RST"; fi
  printf '\033[?25h\n'
  if (( rc )); then tail -n 20 "$out" | sed "s/^/    $DIM/; s/\$/$RST/"; fi
  command rm -f "$out"
  return "$rc"
}

intro() { typed "  ✦ dotfiles  ·  zsh · byobu · starship · vim · tools ✦"; }
outro() { printf '\n'; typed "  ✦ all done ✦  start a new terminal, or: exec zsh -l"; }
