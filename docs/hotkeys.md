# Hotkeys

The first section lists the keys this repo defines. After it are the main default keys of each app it installs. Each app section ends with where to find that app's full list.

- [Custom keys](#custom-keys): byobu, zsh, vim, YASB
- [Clashes](#clashes): keys byobu takes before apps see them
- Defaults: [byobu](#byobu) · [zsh](#zsh) · [fzf](#fzf) · [vim](#vim) · [Windows Terminal](#windows-terminal) · [TUI tools](#tui-tools) · [AI CLIs](#ai-clis) · [Windows apps](#windows-apps)

## Custom keys

### Byobu (`linux/byobu/profile.tmux`)

Browser-style tab keys. Byobu's own F-keys and Alt-arrows still work.

| Key | Does |
|---|---|
| `Ctrl-T` | new tab in the same folder (in vim: passed to vim) |
| `Ctrl-W` `Ctrl-W` | close tab; the second `Ctrl-W` or `y` confirms, any other key cancels (in vim: passed to vim) |
| `Ctrl-PgUp` / `Ctrl-PgDn` | previous / next tab |
| `Alt-1` … `Alt-8`, `Alt-9` | go to tab N; `Alt-9` goes to the last tab |
| `Ctrl-Alt-Left` / `Ctrl-Alt-Right` | move the current tab left / right |
| `Alt-D` | tab popup for every session (below); `Alt-D` again closes it |
| `Ctrl-S` | save tabs now (in vim, nano and Claude Code: passed to the app) |
| `Ctrl-F7` | start / stop logging this pane to `~/logs/` |
| click a tab / a key hint | go to that tab / act like the key (the close hint asks first) |

In the `Alt-D` popup:

| Key | Does |
|---|---|
| type | filter tabs by session, name or folder; typing also searches the text in every pane, scrollback included (exact words; `!word` excludes) |
| `Enter` | go to the tab; for a text match, scroll to that line in copy mode |
| `Ctrl-T` | new tab right after the selected one |
| `F8` | rename the selected tab |
| `Alt-M` | move the selected tab to another session, or to a new one (type a name) |
| `Ctrl-W` `Ctrl-W` | close the selected tab |
| `Esc` / `Alt-D` | close the popup |

### zsh (`linux/zsh/zshrc`)

| Key | Does |
|---|---|
| `Ctrl-Left` / `Ctrl-Right` | back / forward one word |
| `Home` / `End` | start / end of line |
| `Ctrl-Backspace` / `Ctrl-Delete` | delete word before / after the cursor |
| `Up` / `Down` | history search on what is typed so far (zsh-history-substring-search) |
| `Shift-Tab` | previous completion |
| `Ctrl-X` `Ctrl-E` | edit the command line in vim |

### vim (`linux/vim/vimrc`)

Leader is `,`.

| Key | Does |
|---|---|
| `,w` | save |
| `Space` | open / close fold |
| `j` / `k` | move by screen line (wrapped lines) |
| `0` | first non-blank character (`^`) |
| `Ctrl-H/J/K/L` | move to the split left / below / above / right |
| `Alt-J` / `Alt-K` | move the line (or selection) down / up |
| `gV` | select the text last pasted or changed |
| `,Enter` | clear search highlight |
| `,li` | show / hide invisible characters |
| `,ss` | spell check on / off |
| `,n` | line numbers: toggle relative |
| `,uu` | underline the line with `-` |
| `,cl` | delete trailing whitespace |
| `,ml` | add a modeline |
| `,cd` | cd to the current file's folder |
| `,bd` / `,ba` | close the buffer / all buffers |
| `,to` `,te` `,tc` `,tm` `,tn` `,tp` | tab: open this file in a new tab, edit, close, move, next, previous |
| `,yy` (visual) / `,p` | copy to / paste from the system clipboard |
| `,ya` `,yz` (visual) | copy to register a / z |
| `F9` (visual) / `F10` | copy to / paste from the X clipboard with xclip |
| `,cc` `,cb` `,ci` `,cr` | comment: line, block, inline, right (tcomment) |
| `Shift-W` `Shift-B` `Shift-E` | CamelCase / snake_case word motions |
| `F2` | file tree (NERDTree) |
| `,ld` | TODO list (TaskList) |
| `,rt` | rainbow parentheses on / off |
| `F8` | build ctags for the folder |
| `,ev` / `,sv` | edit / reload `~/.vimrc` |
| `:` then `Ctrl-A` `Ctrl-E` `Ctrl-K` `Ctrl-P` `Ctrl-N` | command line: start, end, delete to start, history back / forward |

### YASB (`windows/yasb/config.yaml`)

| Key | Does |
|---|---|
| `Alt-Space` | quick launch (apps, files, `*` prefix for more) |

## Clashes

Inside byobu, these keys reach byobu first, so apps in a tab never see them:
- `Ctrl-T`, `Ctrl-W` (except in vim), `Ctrl-S` (except vim, nano, Claude Code)
- `Alt-D` (zsh: delete word; use `Ctrl-Delete`), `Alt-1`…`Alt-9`, `Alt-Up/Down/Left/Right`, `Ctrl-PgUp/PgDn`, `Ctrl-Alt-Left/Right`
- `F1`…`F9` and their Shift/Ctrl/Alt forms: vim's `F2` (NERDTree), `F8` (ctags) and `F9` only work outside byobu. Use `:NERDTreeToggle` inside it
- `Shift-arrows`, `Alt-Shift-arrows` (pane moves and resizes)
- `Ctrl-A`: byobu's prefix. `Ctrl-A` `a` sends a real `Ctrl-A` to the app (zsh start of line: use `Home`)

`Alt-Space`: YASB's quick launch and PowerToys Run share the default. Whichever starts first gets it; change one in its settings.

## byobu

Byobu runs tmux with the prefix `Ctrl-A`. Full list: `Shift-F1` (byobu help), `Ctrl-A ?` (every tmux key).

| Key | Does |
|---|---|
| `F2` | new tab |
| `F3` / `F4` | previous / next tab |
| `F5` | reload the config |
| `F6` | detach (byobu keeps running) |
| `F7` | copy mode: scroll and search back (keys below) |
| `F8` | rename tab |
| `F9` | byobu config menu |
| `Shift-F2` / `Ctrl-F2` | split the pane top/bottom / side by side |
| `Shift-arrows` | move to the pane in that direction |
| `Shift-F3` / `Shift-F4` | previous / next pane |
| `Alt-Shift-arrows` | resize the pane |
| `Shift-F11` | zoom the pane in / out |
| `Alt-F11` | pane to its own tab |
| `Ctrl-F11` | join the pane into the tab before it |
| `Ctrl-F3` / `Ctrl-F4` | swap the pane with the previous / next one |
| `Shift-F8` | next pane layout |
| `Ctrl-F6` | close the pane (no prompt) |
| `Alt-F9` | type in every pane of the tab at once (toggle) |
| `Shift-F9` / `Ctrl-F9` | run a command in every pane / every tab |
| `Ctrl-Shift-F2` | new session |
| `Alt-Up` / `Alt-Down` | previous / next session |
| `Ctrl-F8` | rename session |
| `Alt-Left` / `Alt-Right` | previous / next tab |
| `Alt-PgUp` / `Alt-PgDn` | scroll back / forward (enters copy mode) |
| `Shift-F7` | save the scrollback to a file and open it |
| `Shift-F5` | cycle the status bar's colors |
| `Shift-F12` | turn byobu's F-keys off / on (for apps that need them) |
| `Shift-F6` | detach without logging out |

With the prefix (`Ctrl-A`, then the key):

| Key | Does |
|---|---|
| `c` | new tab |
| `n` / `p`, `Ctrl-A` | next / previous / last tab |
| `0`…`9`, `'` | go to tab N / to a tab by number |
| `w`, `s` | pick a tab / a session from a tree |
| `,`, `$` | rename tab / session |
| `.` | move the tab to another index or session |
| `%`, `\|` | split |
| `o`, `;`, `q` | next pane, last pane, show pane numbers |
| `z`, `!`, `{` `}` | zoom pane, pane to tab, swap panes |
| `&`, `k` | close the tab (asks) |
| `[`, `]` | copy mode, paste |
| `d` | detach |
| `Ctrl-S` / `Ctrl-R` | save / restore tabs (tmux-resurrect) |
| `t` | clock |
| `:` | tmux command prompt |
| `?` | list every key |

Copy mode (vi keys; `F7` or `Ctrl-A [` to enter):

| Key | Does |
|---|---|
| arrows, `h j k l`, `w b e`, `0 $`, `Ctrl-U` `Ctrl-D` | move |
| `g` / `G` | top / bottom of the scrollback |
| `/` / `?`, `n` / `N` | search down / up, next / previous |
| `Space`, `V`, `v` | start selection, select line, rectangle on / off |
| `Enter` | copy the selection and leave |
| `Esc` / `q` | clear the selection / leave |

The mouse works too: drag selects and copies, the wheel scrolls, double-click selects a word.

## zsh

Emacs keys (`bindkey -e`). Full list: `bindkey` in the shell.

| Key | Does |
|---|---|
| `Ctrl-A` / `Ctrl-E` | start / end of line (`Ctrl-A` is byobu's prefix: use `Home`) |
| `Alt-B` / `Alt-F` | back / forward one word |
| `Ctrl-U` | delete the whole line |
| `Ctrl-K` | delete to the end of the line |
| `Alt-Backspace` | delete word before the cursor |
| `Ctrl-Y` | paste what was last deleted |
| `Ctrl-_` | undo |
| `Alt-.` | insert the previous command's last argument (repeat for older ones) |
| `Alt-Q` | park the line, run another command, get it back |
| `Ctrl-L` | clear the screen |
| `Tab` | complete; again for the menu (arrows to pick) |
| `Right` / `End` | accept the grey autosuggestion |
| `Alt-F` | accept the autosuggestion's next word |

## fzf

| Key | Does |
|---|---|
| `Ctrl-R` | fuzzy history search |
| `Alt-C` | fuzzy cd into a subfolder |
| `Ctrl-T` | fuzzy file path (taken by byobu: use `**` below) |
| `**` `Tab` | fuzzy completion: `vim **<Tab>` files, `cd **<Tab>` folders, `kill -9 **<Tab>` processes, `ssh **<Tab>` hosts |

In any fzf list (including `Alt-D`):

| Key | Does |
|---|---|
| `Up` / `Down`, `Ctrl-K` / `Ctrl-J`, `Ctrl-P` / `Ctrl-N` | move |
| `Tab` / `Shift-Tab` | mark / unmark (multi-select lists) |
| `Enter` | pick |
| `Esc`, `Ctrl-C` | cancel |
| search syntax | `'word` exact, `^start`, `end$`, `!not`, `a \| b` either |

## vim

Full lists: `:help index` (core), `:help <plugin>` (plugins).

Core essentials:

| Key | Does |
|---|---|
| `i` `a` `o` / `Esc` | insert before / after / new line; back to normal mode |
| `h j k l`, `w b e`, `gg G`, `Ctrl-D` `Ctrl-U` | move |
| `v`, `V`, `Ctrl-V` | select characters, lines, a block |
| `y` `d` `c` `p`, `u` `Ctrl-R`, `.` | copy, delete, change, paste; undo, redo; repeat |
| `/` `?` `n` `N`, `*` | search; search the word under the cursor |
| `:w` `:q` `:wq` `:q!` | save, quit, both, quit without saving |
| `:sp` `:vs`, `Ctrl-W` `w` | split; next split |
| `gt` / `gT` | next / previous vim tab |
| `%` | jump to the matching bracket |

Plugins:

| Key | Plugin | Does |
|---|---|---|
| `Ctrl-P` | ctrlp | fuzzy file finder; in it: `Ctrl-J/K` move, `Enter` open, `Ctrl-T` tab, `Ctrl-V` / `Ctrl-X` split, `Ctrl-F` / `Ctrl-B` files/buffers/recent, `F5` refresh |
| in the tree: `o` `t` `s` `i`, `m`, `I`, `C`, `u`, `?` | NERDTree | open, in tab, vsplit, split; file menu; hidden files; cd into; up a level; help |
| `cs"'`, `ds"`, `ysiw)`, `S` (visual) | surround | change, delete, add surrounding characters |
| `gcc`, `gc{motion}`, `gc` (visual) | tcomment | comment the line / the motion / the selection |
| `:G`, `:G blame`, `:Gdiffsplit`, `:Gwrite`; in `:G`: `s` `u` `=` `cc` | fugitive | git status, blame, diff, stage the file; stage, unstage, inline diff, commit |
| `:Ack pattern`; in results: `o` `t` `v` `q` | ack.vim | search the project (ripgrep or ack); open, in tab, vsplit, close |
| `ia` `aa` | argtextobj | a function argument (`cia`, `daa`) |
| `ii` `ai` `iI` `aI` | indent-object | an indentation block |
| `gd`, `K`, `:GoRun` `:GoTest` `:GoBuild` | vim-go | go to definition, docs, run / test / build |
| automatic | delimitMate, endwise, ALE | closes brackets and quotes; adds `end`; lint errors in the gutter (`:ALEDetail`) |

## Windows Terminal

Defaults; full list: `Ctrl-,` → Actions.

| Key | Does |
|---|---|
| `Ctrl-Shift-T` / `Ctrl-Shift-W` | new tab / close pane |
| `Ctrl-Shift-N` | new window |
| `Ctrl-Shift-D` | duplicate tab |
| `Ctrl-Shift-1`…`9` | new tab with profile N |
| `Ctrl-Shift-Space` | new tab menu |
| `Ctrl-Tab` / `Ctrl-Shift-Tab`, `Ctrl-Alt-1`…`9` | next / previous tab, tab N |
| `Alt-Shift-+` / `Alt-Shift--` | split pane right / down |
| `Ctrl-C` / `Ctrl-V`, `Ctrl-Shift-C` / `Ctrl-Shift-V` | copy (with a selection) / paste |
| `Ctrl-Shift-F` | find |
| `Ctrl-Shift-P` | command palette |
| `Ctrl-Shift-Up/Down`, `Ctrl-Shift-PgUp/PgDn` | scroll |
| `Ctrl-+` / `Ctrl--` / `Ctrl-0` | font bigger / smaller / reset |
| `Alt-Enter`, `F11` | full screen |
| `Win-`` ` | quake-mode dropdown window |
| `Ctrl-,` | settings |

## TUI tools

| App | Keys | Full list |
|---|---|---|
| lazygit | `Tab` / `[` `]` panels and tabs, `Space` stage, `a` stage all, `c` commit, `A` amend, `P` push, `p` pull, `f` fetch, `s` stash, `d` discard, `z` / `Z` undo / redo, `e` edit, `/` search, `:` shell, `q` quit. Commits: `s` squash, `r` reword, `F` fixup, `Ctrl-J/K` move | `?` |
| k9s | `:` resource (`:pod`, `:deploy`, `:ctx`, `:ns`), `/` filter, `0` all namespaces, `Enter` open, `d` describe, `l` logs, `s` shell, `e` edit, `y` YAML, `Shift-F` port-forward, `Ctrl-D` delete, `Ctrl-K` kill, `Esc` back, `:q` quit | `?` |
| yazi | arrows / `h j k l`, `Enter` / `o` open, `Space` select, `y` copy, `x` cut, `p` paste, `d` trash, `D` delete, `a` new (end with `/` for a folder), `r` rename, `.` hidden files, `s` / `S` search names / contents, `/` find, `z` zoxide jump, `t` new tab, `q` quit | `F1` or `~` |
| broot | type to filter, `Enter` open / go into, `Esc` back, `Ctrl-Right` / `Ctrl-Left` open / close a preview panel, `Alt-H` hidden files, `Alt-I` git-ignored files, `Space` or `:` then a verb (`:rm`, `:mv`, `:cp`), `Ctrl-Q` quit | `?` |
| btop | `Esc` menu, `1`…`4` show CPU / memory / network / processes, `f` filter, `e` tree, `t` / `k` terminate / kill, `Enter` process details, `q` quit | `F1` |
| gdu / ncdu | arrows, `Enter` open, `Left` up, `d` delete, `n` / `s` / `C` sort by name / size / count, `q` quit | `?` |
| jless | `j` / `k` move, `h` / `l` collapse / expand, `Space` toggle, `c` / `e` collapse / expand siblings, `/` `?` `n` `N` search, `yy` copy value, `yp` copy path, `q` quit | `F1` |
| fx | arrows, `e` / `E` expand, `c` / `C` collapse, `/` search, `.` go to path, `q` quit | `?` |
| termshark | `/` display filter, `Tab` next pane, `Enter` select, `q` quit | `?` |
| viddy | `Space` time machine (step through past runs), `s` pause, `d` diff, `/` search, `q` quit | `?` |
| less, bat, man | `Space` / `b` page, `g` / `G` top / bottom, `/` `n` `N` search, `q` quit | `h` |

## AI CLIs

| App | Keys | Full list |
|---|---|---|
| Claude Code | `Esc` interrupt, `Esc` `Esc` go back to an earlier message, `Shift-Tab` permission mode (auto-accept / plan), `Ctrl-R` search history, `Ctrl-V` paste an image, `\` `Enter` new line, `!` shell command, `@` mention a file, `/` command, `Ctrl-C` twice or `Ctrl-D` quit | `/help`, `?` |
| Codex | `Esc` interrupt, `Esc` `Esc` edit the previous message, `@` file, `/` command, `Ctrl-C` quit | `/help` |
| OpenCode | `Tab` switch agent (build / plan), `Esc` interrupt, `Ctrl-X` then `N` new session, `L` sessions, `M` models, `/` command | `Ctrl-X H` or `/help` |

## Windows apps

Defaults; change them in each app's settings.

| App | Keys |
|---|---|
| PowerToys | `Win-Alt-Space` Command Palette, `Alt-Space` PowerToys Run (clashes with YASB), `Win-Ctrl-T` always on top, `Win-Shift-C` color picker, `Win-Shift-T` text from screen (OCR), ``Win-Shift-` `` FancyZones editor, `Win-Ctrl-Shift-M` screen ruler, `Win-Shift-V` advanced paste, `Ctrl-Space` Peek (in Explorer), `Ctrl` twice find my mouse |
| Sysinternals ZoomIt | `Ctrl-1` zoom, `Ctrl-2` draw, `Ctrl-3` break timer, `Ctrl-4` live zoom, `Ctrl-5` record (while running) |
| Process Explorer | `Ctrl-F` find a handle or DLL, `Ctrl-H` / `Ctrl-D` show handles / DLLs, `Ctrl-T` tree view, `Del` kill process |
| Everything | type to search, `Enter` open, `Ctrl-Enter` open folder, `Ctrl-Shift-C` copy full path, `F2` rename |
| Wireshark | `Ctrl-E` start / stop capture, `Ctrl-K` capture options, `Ctrl-/` display filter, `Ctrl-F` find packet, `Ctrl-.` / `Ctrl-,` next / previous packet |
| VS Code | `Ctrl-Shift-P` commands, `Ctrl-P` open file, ``Ctrl-` `` terminal, `Ctrl-B` sidebar, `Ctrl-Shift-E/F/G/X` explorer / search / git / extensions, `Ctrl-D` next match, `Alt-Up/Down` move line, `Ctrl-/` comment, `F12` definition, `Ctrl-K Ctrl-S` all keys. Your synced keybindings override these |
