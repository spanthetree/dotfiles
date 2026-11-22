#!/usr/bin/env bash
# GNOME-style window handling for Hyprland. Linked to ~/.config/hypr/dotfiles-windows.sh; bound in dotfiles.lua.
#   switch [prev]  the Alt-Tab list (a second Tab with Alt held): every window, most recently used first; release Alt picks
#   minimize       hide the active window in special:minimized
#   restore        menu of minimized windows; the pick comes back to the current workspace
#   count          waybar module: minimized windows (empty when none, which hides the module)
set -uo pipefail

MIN=special:minimized
SIGNAL=11  # waybar "signal" of custom/minimized (the desktop setup's modules use 9)
ROFI_CONF=$HOME/.config/hypr/rofi/config.rasi

refresh_bar() { pkill -RTMIN+$SIGNAL -x waybar 2>/dev/null || true; }

# lua <code>: run Lua in Hyprland. `win` is the window with address $2 (nil when it's gone).
lua_on_window() {
  hyprctl eval "local win; for _, w in ipairs(hl.get_windows()) do
      if tostring(w.address):gsub('^0x', '') == ('$2'):gsub('^0x', '') then win = w end
    end
    if win then $1 end" >/dev/null
}

# bring <address>: move a window out of the minimized workspace to the current one, then focus it
bring() {
  lua_on_window "
    local cur = hl.get_active_workspace()
    if win.workspace and win.workspace.name == '$MIN' and cur then
      hl.dispatch(hl.dsp.window.move({ window = win, workspace = tostring(cur.id), follow = false }))
    end
    hl.dispatch(hl.dsp.focus({ window = win }))" "$1"
  refresh_bar
}

# rows <jq filter>: "address<TAB>title<TAB>class<TAB>workspace" of the matching clients, most recently used first.
# No field is ever empty: `read` with a tab IFS would merge it with the next one.
rows() {
  hyprctl clients -j | jq -r "[.[] | select(.mapped and $1)] | sort_by(.focusHistoryID) | .[]
    | (if .class == \"\" then \"window\" else .class end) as \$class
    | [.address, (if .title == \"\" then \$class else .title | gsub(\"[\\t\\n]\"; \" \") end), \$class, .workspace.name]
    | @tsv"
}

# menu <rows> <selected row> <rofi args...>: show the rows, print the picked address
menu() {
  local list=$1 sel=$2; shift 2
  local i conf=()
  [[ -f $ROFI_CONF ]] && conf=(-config "$ROFI_CONF")
  i=$(while IFS=$'\t' read -r _ title class ws; do
        [[ $ws == "$MIN" ]] && ws=minimized
        printf '%s  ·  %s\0icon\x1f%s\n' "$title" "$ws" "${class,,}"
      done <<<"$list" |
      rofi -dmenu -i -show-icons -format i -selected-row "$sel" -p "${PROMPT:-windows}" \
        "${conf[@]}" "$@") || return 1
  [[ -n $i ]] && sed -n "$((i + 1))p" <<<"$list" | cut -f1
}

case "${1:-}" in
switch)
  # dotfiles.lua put Hyprland in the empty dotfiles-switch submap, so Alt-Tab reaches rofi instead of this bind
  trap 'hyprctl dispatch "hl.dsp.submap(\"reset\")" >/dev/null 2>&1' EXIT
  list=$(rows 'true')
  [[ -n $list ]] || exit 0
  n=$(wc -l <<<"$list")
  # The first Alt-Tab already switched (dotfiles.lua), so row 0 is that window and row 1 the one you came from:
  # this second Tab goes on to row 2. Shift-Tab: the least recent.
  if [[ ${2:-} == prev ]]; then sel=$((n - 1)); else sel=$((n > 2 ? 2 : n - 1)); fi
  # a switcher, not a search: no input bar (typing still filters)
  addr=$(PROMPT=switch menu "$list" "$sel" \
    -theme-str 'inputbar { enabled: false; } mode-switcher { enabled: false; } message { enabled: false; }' \
    -kb-element-next '' -kb-element-prev '' -kb-mode-complete '' \
    -kb-row-down 'Alt+Tab,Down,Control+n' \
    -kb-row-up 'Alt+ISO_Left_Tab,Alt+Shift+ISO_Left_Tab,Alt+Shift+Tab,Up,Control+p' \
    -kb-accept-entry '!Alt+Alt_L,!Alt+Shift+Alt_L,!Alt_L,Return,KP_Enter' \
    -kb-cancel 'Escape,Alt+Escape') || exit 0
  [[ -n $addr ]] && bring "$addr"
  ;;
minimize)
  hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = '$MIN', follow = false }))" >/dev/null
  refresh_bar
  ;;
restore)
  pkill -x rofi && exit 0
  list=$(rows ".workspace.name == \"$MIN\"")
  if [[ -z $list ]]; then
    notify-send -t 2000 "No minimized windows" 2>/dev/null || true
    exit 0
  fi
  addr=$(PROMPT=restore menu "$list" 0) || exit 0
  [[ -n $addr ]] && bring "$addr"
  ;;
count)
  titles=$(rows ".workspace.name == \"$MIN\"" | cut -f2)
  n=0; [[ -n $titles ]] && n=$(wc -l <<<"$titles")
  if ((n == 0)); then
    echo '{"text": ""}'
  else
    jq -cn --arg n "$n" --arg t "$titles" \
      '{text: ("󰖰 " + $n), tooltip: ("Minimized (click to restore):\n" + $t), class: "minimized"}'
  fi
  ;;
*)
  echo "usage: ${0##*/} switch [prev] | minimize | restore | count" >&2
  exit 2
  ;;
esac
