# Byobu / tmux: SynthWave '84, status rows inherit the terminal background
source $BYOBU_PREFIX/share/byobu/profiles/tmux

# General
set -g mouse on
set -g focus-events on
set -g history-limit 20000
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
set -g automatic-rename on
set -g allow-rename off
setw -g monitor-activity on
set -g visual-activity off
set -g set-clipboard on
set -g escape-time 10
# Byobu attaches each new terminal as a grouped session; give each one its own window
set-hook -g session-created 'if -F "#{session_grouped}" "new-window"'

# Colors
set -g status-style 'fg=#f4eaff,bg=default'
set -g message-style 'fg=#111018,bg=#b893ce'
set -g message-command-style 'fg=#36f9f6,bg=#111018'
set -g pane-border-style 'fg=#49375f'
set -g pane-active-border-style 'fg=#ff7edb'
set -g mode-style 'fg=#111018,bg=#36f9f6'

# Status: row 0 spacer, row 1 tabs, row 2 git/lang/k8s context, row 3 metrics
set -g status 4
set -g status-position bottom
set -g status-interval 5

# Active-tab pulse: tab-pulse toggles @pulse-on and redraws ~every 0.6s
set -g @pulse-on 1
run -b '$HOME/.config/byobu/bin/tab-pulse'

# Window index as Nerd Font boxed digits (codepoints are not sequential, hence the map)
set -g @box-fill '#{s/9/󰎼/:#{s/8/󰎹/:#{s/7/󰎶/:#{s/6/󰎳/:#{s/5/󰎱/:#{s/4/󰎭/:#{s/3/󰎪/:#{s/2/󰎧/:#{s/1/󰎤/:#{s/0/󰎡/:#{window_index}}}}}}}}}}}'
set -g @box-line '#{s/9/󰎾/:#{s/8/󰎻/:#{s/7/󰎸/:#{s/6/󰎵/:#{s/5/󰎰/:#{s/4/󰎮/:#{s/3/󰎬/:#{s/2/󰎩/:#{s/1/󰎦/:#{s/0/󰎣/:#{window_index}}}}}}}}}}}'

# Session badge solid; tabs transparent. Active tab background pulses (see tab-pulse).
set -g status-left '#[fg=#111018,bg=#b893ce,bold] #{?session_grouped,#{session_group},#S} #[fg=#f4eaff,bg=default,nobold] '
set -g status-right '#[fg=#36f9f6,bg=default]#{window_panes} panes '
set -g window-status-separator ' '
set -g window-status-style 'fg=#b893ce,bg=default'
set -g window-status-current-style 'fg=#ff7edb,bg=default,bold'
set -g window-status-activity-style 'fg=#fede5d,bg=default,bold'
set -g window-status-format ' #{E:@box-line} #W '
set -g window-status-current-format '#[bg=#{?@pulse-on,##ff7edb,default},fg=#{?@pulse-on,##111018,##ff7edb}] #{?@pulse-on,#{E:@box-fill},#{E:@box-line}} #W #[bg=default]'

# Hint styles for the clickable key hints on row 2
set -g @key '#[fg=#36f9f6,bold]'
set -g @hint '#[fg=#a99bbd,nobold]'

set -g 'status-format[0]' '#[bg=default,fill=default] '
# Each tab applies its own style and resets after, so the pulse can't bleed into neighbours
set -g 'status-format[1]' '#[bg=default,fill=default]#{E:status-left}#{W:#[range=window|#{window_index}]#[#{?window_activity_flag,#{E:window-status-activity-style},#{E:window-status-style}}]#{E:window-status-format}#[norange]#[default],#[range=window|#{window_index}]#[#{E:window-status-current-style}]#{E:window-status-current-format}#[norange]#[default]}#[align=right]#{E:status-right}'
# Row 2: starship-status.toml modules for the active pane's directory
set -g 'status-format[2]' '#[bg=default,fill=default]#[align=centre]#($HOME/.config/byobu/bin/context-status #{q:pane_current_path})'
set -g 'status-format[3]' '#[bg=default,fill=default]#[align=left]#[range=user|new]#{E:@key} F2#{E:@hint} new #[norange]#[range=user|prev]#{E:@key} F3#{E:@hint} prev #[norange]#[align=centre]#($HOME/.config/byobu/bin/retrowave-status)  #[fg=#fede5d]󰥔 %H:%M:%S#[align=right]#[range=user|next]#{E:@hint} next #{E:@key}F4 #[norange]#[range=user|close]#{E:@hint} close #{E:@key}^F6 #[norange]'

# Clicks: tabs select, row-2 hints act like their keys (close asks first)
bind -n MouseDown1Status {
  if -F '#{==:#{mouse_status_range},window}' { select-window -t = } {
  if -F '#{==:#{mouse_status_range},new}' { new-window -c '#{pane_current_path}' } {
  if -F '#{==:#{mouse_status_range},prev}' { previous-window } {
  if -F '#{==:#{mouse_status_range},next}' { next-window } {
  if -F '#{==:#{mouse_status_range},close}' { confirm-before -p 'Close pane? (y/n)' kill-pane } } } } }
}
