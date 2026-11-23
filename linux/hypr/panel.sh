#!/usr/bin/env bash
# Which panel runs under Hyprland: wayle (the default where it's installed: bar, notifications and OSD in one;
# packages.yaml, config in linux/wayle), or the desktop setup's waybar + swaync. Linked to ~/.config/hypr/dotfiles-panel.sh.
#   dotfiles-panel.sh wayle     switch to wayle, now and at every login
#   dotfiles-panel.sh waybar    switch back
#   dotfiles-panel.sh           say which one is chosen
#   dotfiles-panel.sh login     (linux/hypr/dotfiles.lua, at login) start wayle if it's the choice
#   dotfiles-panel.sh swaync    (linux/hypr/swaync-panel.conf) fails while wayle is the choice, so swaync isn't started
#   dotfiles-panel.sh key <Volume.sh|Brightness.sh> <arg>   (the volume and brightness keys, from dotfiles.lua)
#                               with waybar, the desktop setup's script (it notifies); with wayle, the same change
#                               without a notification: wayle's own indicator shows it, and its notifications
#                               would stack (it ignores the hint that makes each replace the last)
# The choice is a per-machine file, ~/.config/hypr/dotfiles-panel (wayle or waybar); no file = wayle if it's installed,
# else waybar.
# The desktop setup restarts waybar and swaync by itself (wallpaper changes, lid, display profiles, Refresh.sh).
# While wayle is the choice, a watcher closes them again when they come back.
set -uo pipefail
CHOICE=$HOME/.config/hypr/dotfiles-panel
STARTUP=$HOME/.config/hypr/scripts/WaybarStartup.sh

chosen() {
  case $(cat "$CHOICE" 2>/dev/null) in
    waybar) echo waybar ;;
    wayle) echo wayle ;;
    *) if [[ -x $HOME/.local/bin/wayle ]] || command -v wayle >/dev/null; then echo wayle; else echo waybar; fi ;;
  esac
}
stop_waybar() {
  pkill -x waybar; pkill -x .waybar-wrapped
  systemctl --user stop swaync.service 2>/dev/null; pkill -x swaync
}
audio_defaults() { pactl get-default-sink 2>/dev/null; pactl get-default-source 2>/dev/null; }
wayle_audio() {  # what wayle takes for the defaults (its audio service on D-Bus)
  local p
  for p in DefaultSink DefaultSource; do
    busctl --user get-property com.wayle.Audio1 /com/wayle/Audio com.wayle.Audio1 "$p" 2>/dev/null | sed 's/^s "//; s/"$//'
  done
}
audio_nudge() {  # make wayle read the defaults again: a default change does, so move the default input away and back
  local src alt
  src=$(pactl get-default-source 2>/dev/null) || return
  alt=$(pactl list short sources 2>/dev/null | cut -f2 | grep -vxF "$src" | head -1)
  [[ -n $alt ]] || return
  pactl set-default-source "$alt" && pactl set-default-source "$src"
}
guard() {  # while wayle is the choice: keep waybar and swaync away, and keep wayle's audio modules right
  # When the default device changes (headphones coming or going, a Bluetooth profile switch), PulseAudio can name the
  # new default before wayle has added that device; wayle (0.7) then drops the default and its volume and microphone
  # modules go blank until the next default change. So when wayle's defaults stay different from PulseAudio's, make
  # one (audio_nudge: only the input moves, for a moment; output stays put), and restart wayle only if that fails.
  local stale=0
  while [[ $(chosen) == wayle ]]; do
    if pgrep -x waybar >/dev/null || pgrep -x .waybar-wrapped >/dev/null || pgrep -x swaync >/dev/null; then stop_waybar; fi
    if pgrep -x wayle >/dev/null && [[ $(wayle_audio) != "$(audio_defaults)" ]]; then
      stale=$((stale + 1))
      if ((stale == 2)); then audio_nudge
      elif ((stale >= 4)); then restart_wayle; stale=0; sleep 3; fi
    else
      stale=0
    fi
    sleep 2
  done
}
live_hyprland() {  # a shell in byobu can carry a dead HYPRLAND_INSTANCE_SIGNATURE (byobu outlived a Hyprland
  # restart): a panel started from it loses its Hyprland modules (workspaces, window title, keyboard, key mode).
  # So the panels are started through Hyprland (hypr_exec), which only needs hyprctl to reach the live one
  hyprctl version >/dev/null 2>&1 && return 0
  local d
  for d in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/; do
    if HYPRLAND_INSTANCE_SIGNATURE=$(basename "$d") hyprctl version >/dev/null 2>&1; then
      export HYPRLAND_INSTANCE_SIGNATURE; HYPRLAND_INSTANCE_SIGNATURE=$(basename "$d"); return 0
    fi
  done
}
key() {  # key <Volume.sh|Brightness.sh> <arg>: see the top
  local script=$1 arg=${2:-}
  if [[ $(chosen) != wayle ]]; then exec "$HOME/.config/hypr/scripts/$script" "$arg"; fi
  local muted; muted=$(pamixer --get-mute 2>/dev/null)
  case "$script $arg" in
    'Volume.sh --inc'|'Volume.sh --inc-precise'|'Volume.sh --dec'|'Volume.sh --dec-precise')
      if [[ $muted == true ]]; then pamixer -u; return; fi  # the desktop scripts unmute first, as here
      local step=5; [[ $arg == *precise ]] && step=1
      if [[ $arg == --inc* ]]; then pamixer -i "$step" --allow-boost --set-limit 150; else pamixer -d "$step"; fi ;;
    'Volume.sh --toggle') pamixer -t ;;
    'Volume.sh --toggle-mic') pamixer --default-source -t ;;
    'Brightness.sh --inc'|'Brightness.sh --dec')
      local cur new; cur=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
      if [[ $arg == --inc ]]; then new=$((cur + 10)); else new=$((cur - 10)); fi
      ((new < 5)) && new=5; ((new > 100)) && new=100  # as Brightness.sh: never fully dark
      brightnessctl -q set "${new}%" ;;
    *) exec "$HOME/.config/hypr/scripts/$script" "$arg" ;;
  esac
}
hypr_exec() {  # hypr_exec <command>: run it from Hyprland, so it gets Hyprland's own (current) environment
  if live_hyprland; then hyprctl dispatch "hl.dsp.exec_cmd([[$1]])" >/dev/null
  else setsid sh -c "$1" >/dev/null 2>&1 < /dev/null & fi
}
restart_wayle() {  # the guard's: wayle again, through Hyprland (live environment)
  wayle panel stop >/dev/null 2>&1
  hypr_exec "$(command -v wayle) panel start"
}
start_wayle() {
  command -v wayle >/dev/null || { echo "wayle isn't installed: re-run the dotfiles installer" >&2; return 1; }
  wayle panel stop >/dev/null 2>&1  # one started with a dead signature keeps it: start afresh
  stop_waybar
  hypr_exec "$(command -v wayle) panel start"
  pgrep -f 'dotfiles-panel.sh guard' >/dev/null || setsid "$0" guard >/dev/null 2>&1 < /dev/null &
}

case ${1:-} in
  wayle)
    echo wayle >| "$CHOICE"
    start_wayle && echo "wayle on (back with: $0 waybar)" ;;
  waybar)
    echo waybar >| "$CHOICE"
    pkill -f 'dotfiles-panel.sh guard'
    command -v wayle >/dev/null && wayle panel stop >/dev/null 2>&1
    systemctl --user start swaync.service 2>/dev/null || pgrep -x swaync >/dev/null || hypr_exec swaync
    if [[ -x $STARTUP ]]; then hypr_exec "$STARTUP --restart"; else hypr_exec waybar; fi
    echo "waybar on" ;;
  login) [[ $(chosen) == wayle ]] && { sleep 3; start_wayle; } ;;  # after the desktop setup started waybar
  guard) guard ;;
  swaync) [[ $(chosen) != wayle ]] || exit 1 ;;  # (linux/hypr/swaync-panel.conf) swaync only with waybar
  key) shift; key "$@" ;;
  '') chosen ;;
  *) echo "usage: $0 [wayle | waybar]" >&2; exit 2 ;;
esac
exit 0
