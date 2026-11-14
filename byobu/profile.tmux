# Byobu / tmux: SynthWave '84, status rows inherit the terminal background
source $BYOBU_PREFIX/share/byobu/profiles/tmux
# New tabs run login shells (byobu sets default-command to a plain $SHELL); ~/.zprofile guards against relaunching byobu
set -g default-command ''

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
set -g status-right '#[range=user|search]#{E:@hint}search #{E:@key}M-d#[norange]  #[fg=#36f9f6,bg=default,nobold]#{window_panes} panes '
set -g window-status-separator ' '
set -g window-status-style 'fg=#b893ce,bg=default'
set -g window-status-current-style 'fg=#ff7edb,bg=default,bold'
set -g window-status-activity-style 'fg=#fede5d,bg=default,bold'
# Long tab names cut at 24 chars
set -g @tab-name '#{=/24/…:window_name}'
set -g window-status-format ' #{E:@box-line} #{E:@tab-name} '
set -g window-status-current-format '#[bg=#{?@pulse-on,##ff7edb,default},fg=#{?@pulse-on,##111018,##ff7edb}] #{?@pulse-on,#{E:@box-fill},#{E:@box-line}} #{E:@tab-name} #[bg=default]'

# Hint styles for the clickable key hints on row 2
set -g @key '#[fg=#36f9f6,bold]'
set -g @hint '#[fg=#a99bbd,nobold]'

set -g 'status-format[0]' '#[bg=default,fill=default] '
# Tabs scroll when they overflow (list=on), keeping the current tab in view (list=focus), with ◀ ▶ markers.
# Each tab applies its own style and resets after, so the pulse can't bleed into neighbours
set -g 'status-format[1]' '#[bg=default,fill=default]#{E:status-left}#[list=on align=left]#[list=left-marker]#{E:@key}◀ #[list=right-marker]#{E:@key} ▶#[list=on]#{W:#[range=window|#{window_index}]#[#{?window_activity_flag,#{E:window-status-activity-style},#{E:window-status-style}}]#{E:window-status-format}#[norange]#[default],#[range=window|#{window_index}]#[list=focus]#[#{E:window-status-current-style}]#{E:window-status-current-format}#[norange]#[default]#[list=on]}#[nolist align=right] #{E:status-right}'
# Row 2: starship-status.toml modules for the active pane's directory
set -g 'status-format[2]' '#[bg=default,fill=default]#[align=centre]#($HOME/.config/byobu/bin/context-status #{q:pane_current_path})'
set -g 'status-format[3]' '#[bg=default,fill=default]#[align=left]#[range=user|new]#{E:@key} ^T#{E:@hint} new #[norange]#[range=user|prev]#{E:@key} ^PgUp#{E:@hint} prev #[norange]#[align=centre]#($HOME/.config/byobu/bin/retrowave-status)  #[fg=#fede5d]󰥔 %H:%M:%S#[align=right]#[range=user|next]#{E:@hint} next #{E:@key}^PgDn #[norange]#[range=user|close]#{E:@hint} close #{E:@key}^W #[norange]'

# Clicks: tabs select, row-2 hints act like their keys (close asks first)
bind -n MouseDown1Status {
  if -F '#{==:#{mouse_status_range},window}' { select-window -t = } {
  if -F '#{==:#{mouse_status_range},new}' { new-window -c '#{pane_current_path}' } {
  if -F '#{==:#{mouse_status_range},prev}' { previous-window } {
  if -F '#{==:#{mouse_status_range},next}' { next-window } {
  if -F '#{==:#{mouse_status_range},search}' { send-keys -K M-d } {
  if -F '#{==:#{mouse_status_range},close}' { confirm-before -p 'Close pane? (y/n)' kill-pane } } } } } }
}

# Browser-style tab keys (byobu's F-keys and Alt-arrows still work).
# In vim, Ctrl-T/Ctrl-W pass through to vim; elsewhere Ctrl-W asks before closing.
set -g @in-vim '#{m/r:^(n?vim?|vimdiff|view)$,#{pane_current_command}}'
bind -n C-t if -F '#{E:@in-vim}' { send-keys C-t } { new-window -c '#{pane_current_path}' }
# Close confirm: Ctrl-W again or y closes, any other key cancels (a key table, since prompts treat Ctrl-W as delete-word)
bind -n C-w if -F '#{E:@in-vim}' { send-keys C-w } { switch-client -T close-tab ; display -d 0 'Close tab? (y/n)' }
bind -T close-tab C-w kill-pane
bind -T close-tab y kill-pane
bind -T close-tab Any display -d 1 ''
# Ctrl-S saves the tabs now (resurrect); vim, nano and Claude Code still get it. Costs zsh's forward history search.
set -g @keeps-c-s '#{m/r:^(n?vim?|vimdiff|view|nano|claude)$,#{pane_current_command}}'
bind -n C-s if -F '#{E:@keeps-c-s}' { send-keys C-s } { run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh' }
bind -n C-PPage previous-window
bind -n C-NPage next-window
# Ctrl-Alt-Left/Right move the current tab (byobu's Ctrl-Shift-F3/F4 still work)
bind -n C-M-Left swap-window -d -t :-1
bind -n C-M-Right swap-window -d -t :+1
# Alt-1..8 jump to that tab, Alt-9 to the last one
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4
bind -n M-5 select-window -t :5
bind -n M-6 select-window -t :6
bind -n M-7 select-window -t :7
bind -n M-8 select-window -t :8
bind -n M-9 select-window -t :$
# Alt-d: fuzzy search tabs by name, folder or pane text, in a popup (bin/tab-search)
bind -n M-d display-popup -E -w 80% -h 60% -T ' tabs ' '$HOME/.config/byobu/bin/tab-search'
# Ctrl-F7: toggle logging this pane to ~/logs (F7 is scrollback, Shift-F7 saves it)
bind -n C-F7 pipe-pane -o "mkdir -p ~/logs && cat >> ~/logs/#{session_group}-#{window_index}.#{pane_index}-$(date +%%Y%%m%%d-%%H%%M%%S).log" \; display -d 2000 '#{?pane_pipe,logging to ~/logs,logging stopped}'

# Sessions survive WSL/reboot: resurrect saves, continuum autosaves every 15 min and restores on start.
# Byobu's per-terminal grouped sessions are dropped from saves; the base session holds all tabs.
set -g @resurrect-hook-post-save-layout "sed -i '/^grouped_session/d'"
# Restore is ours (bin/restore-tabs): continuum's skips when several terminals start byobu at once.
set -g @continuum-restore 'off'
run -b '~/.tmux/plugins/tmux-resurrect/resurrect.tmux'
run -b '~/.tmux/plugins/tmux-continuum/continuum.tmux'
run -b '$HOME/.config/byobu/bin/restore-tabs'
