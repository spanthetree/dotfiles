#!/usr/bin/env bash
# Screen recording on/off, like GNOME's Ctrl-Alt-Shift-R. Bound in linux/hypr/dotfiles.lua (Hyprland, linked to
# ~/.config/hypr/dotfiles-record.sh) and linux/cosmic/shortcuts.ron (COSMIC, linked to ~/.local/bin/dotfiles-record).
#   dotfiles-record          start recording the screen, or stop a running recording
#   dotfiles-record region   the same, for an area picked with the mouse (slurp)
# Hyprland: wf-recorder (its focused monitor). Elsewhere (COSMIC): wl-screenrec, as COSMIC has no wlroots
# screencopy, which wf-recorder needs; it takes the only display (with several, record an area).
# Files go to ~/Videos/Screencasts (GNOME's folder), named by date and time. No sound, as in GNOME.
set -uo pipefail
notify() { notify-send -e -u low -a "Screen recording" -i media-record "$@" 2>/dev/null || true; }

if pkill -INT -x wf-recorder || pkill -INT -x wl-screenrec; then  # SIGINT lets it finish the file
  notify "Recording saved" "in ~/Videos/Screencasts"
  exit 0
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v wf-recorder >/dev/null; then rec=wf-recorder
elif command -v wl-screenrec >/dev/null; then rec=wl-screenrec
else notify "No screen recorder installed" "re-run the dotfiles installer"; exit 1; fi

dir=$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Screencasts
mkdir -p "$dir"
file="$dir/Screencast from $(date '+%Y-%m-%d %H-%M-%S').mp4"
args=()
if [[ ${1:-} == region ]]; then
  geom=$(slurp) || exit 0  # Escape: nothing recorded
  args=(-g "$geom")
elif [[ $rec == wf-recorder ]]; then
  args=(-o "$(hyprctl activeworkspace -j | jq -r .monitor)")
fi
notify "Recording" "press the same keys again to stop"
"$rec" "${args[@]}" -f "$file" >/dev/null 2>&1 && exit 0
# it ended with an error rather than our SIGINT (wl-screenrec with several displays, or no capture permission)
[[ -s $file ]] || command rm -f "$file"
notify "Recording failed" "$( [[ $rec == wl-screenrec && -z ${geom:-} ]] && echo 'several displays? record an area: Ctrl-Alt-Shift-A' || echo "$rec stopped with an error")"
