# Byobu's "emacs mode" (byobu-ctrl-a emacs): Ctrl-A goes to the shell (start of line), F12 is the prefix.
# Byobu reads this file after profile.tmux, so the prefix must be set here.
unbind-key -n C-a
set -g prefix F12
set -g prefix2 None
