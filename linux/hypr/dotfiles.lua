-- Hyprland: this repo's additions. Only used when Hyprland is installed (e.g. by a Hyprland desktop setup):
-- linked to ~/.config/hypr/dotfiles.lua and loaded from the end of UserConfigs/user_keybinds.lua,
-- a file the desktop setup's updates keep. Everything else stays the desktop setup's.
-- The aim: GNOME habits (Alt-Tab, minimize, click to focus, Super for the overview) on top of tiling.

local home = os.getenv("HOME") or ""
local hypr = home .. "/.config/hypr"
local windows = hypr .. "/dotfiles-windows.sh"  -- linux/hypr/windows.sh

-- The desktop setup's helper: bind/unbind cover each spelling of a key (Tab/tab, SPACE/space)
local helper = dofile(hypr .. "/lua/user_keybinds_helper.lua")
local bind, unbind, dispatch, exec_cmd = helper.bind, helper.unbind, helper.dispatch, helper.exec_cmd
local function rebind(mods, key, action, description, opts)
  unbind(mods, key)
  opts = opts or {}
  opts.description = description
  bind(mods, key, action, opts)
end
local function have(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

-- hyprshell (linux/hyprshell/config.toml), where it's installed (GTK 4.18+: Ubuntu 26.04 on): it takes Alt-Tab and
-- Super-Space, binding them itself over IPC once it runs. Until then, the rofi versions below.
local hyprshell = home .. "/.local/bin/hyprshell"
local hyprshell_conf = home .. "/.config/hyprshell/config.toml"
local use_hyprshell = have(hyprshell) and have(hyprshell_conf)

-- ---------------------------------------------------------------- keys
local launcher = "pkill rofi || true; $HOME/.config/hypr/scripts/RofiFocusedWallpaperLink.sh >/dev/null 2>&1 || true; "
  .. "rofi -show drun -modi drun,filebrowser,run,window -config $HOME/.config/hypr/rofi/config.rasi"
-- Super-Space: the app launcher, as on Windows (yasb). Floating moves to Super-Shift-Space.
if use_hyprshell then
  unbind("SUPER", "SPACE")
else
  rebind("SUPER", "SPACE", exec_cmd(launcher), "app launcher")
end
rebind("SUPER SHIFT", "SPACE", dispatch("togglefloating", ""), "Float current window")
-- Tapping Super alone: the workspace overview, like GNOME's Activities (Super-A too). Hyprspace (packages.yaml):
-- every workspace in a strip; click one to go there, drag windows between them (or onto the empty one at the end
-- for a new workspace), Escape or a click closes it. Until the plugin is loaded (hyprpm reloads the config once
-- it is), the desktop setup's Quickshell overview.
local overview = hl.plugin and hl.plugin.overview
local toggle_overview = overview and function() overview.toggle() end
  or exec_cmd("$HOME/.config/hypr/scripts/OverviewToggle.sh")
hl.bind("SUPER + Super_L", toggle_overview, { release = true, description = "workspace overview (tap Super)" })
rebind("SUPER", "A", toggle_overview, "workspace overview")
if overview then
  hl.config({
    plugin = {
      overview = {
        exitOnSwitch = true,         -- clicking a workspace goes there and closes the overview
        showNewWorkspace = true,     -- an empty one at the end: drop a window there for a new workspace
        showEmptyWorkspace = true,
        panelColor = "rgba(262335cc)",           -- SynthWave '84 background
        workspaceActiveBorder = "rgba(ff7edbff)", -- its pink
        workspaceInactiveBorder = "rgba(495495ff)",
      },
    },
  })
end

-- Super-Tab / Super-Shift-Tab: next / previous workspace (the desktop setup also had group switching there)
rebind("SUPER", "Tab", dispatch("workspace", "m+1"), "next workspace")
rebind("SUPER SHIFT", "Tab", dispatch("workspace", "m-1"), "previous workspace")
-- Ctrl-Alt-Left/Right: the same, as in GNOME (byobu moves tabs with Ctrl-Alt-PgUp/PgDn instead)
rebind("CTRL ALT", "Left", dispatch("workspace", "m-1"), "previous workspace")
rebind("CTRL ALT", "Right", dispatch("workspace", "m+1"), "next workspace")

-- Ctrl-Alt-Shift-R: start / stop screen recording, as in GNOME (linux/desktop/record.sh). Ctrl-Alt-Shift-A: an area.
local record = hypr .. "/dotfiles-record.sh"
rebind("CTRL ALT SHIFT", "R", exec_cmd(record), "screen recording on/off (focused monitor)")
rebind("CTRL ALT SHIFT", "A", exec_cmd(record .. " region"), "screen recording on/off (pick an area)")

-- Volume and brightness keys: the desktop setup's Volume.sh / Brightness.sh with waybar; with wayle (its own on-screen
-- indicator) the same change without their notifications, which stack there. linux/hypr/panel.sh decides.
local panel = hypr .. "/dotfiles-panel.sh key "
for _, k in ipairs({
  { "", "XF86AudioRaiseVolume", "Volume.sh --inc", "volume up", true },
  { "", "XF86AudioLowerVolume", "Volume.sh --dec", "volume down", true },
  { "ALT", "XF86AudioRaiseVolume", "Volume.sh --inc-precise", "volume up precise", true },
  { "ALT", "XF86AudioLowerVolume", "Volume.sh --dec-precise", "volume down precise", true },
  { "", "XF86AudioMute", "Volume.sh --toggle", "toggle mute", false },
  { "", "XF86AudioMicMute", "Volume.sh --toggle-mic", "toggle mic mute", false },
  { "", "XF86MonBrightnessUp", "Brightness.sh --inc", "increase monitor brightness", true },
  { "", "XF86MonBrightnessDown", "Brightness.sh --dec", "decrease monitor brightness", true },
  { "CTRL ALT", "equal", "Brightness.sh --inc", "increase brightness", true },
  { "CTRL ALT", "minus", "Brightness.sh --dec", "decrease brightness", true },
}) do
  rebind(k[1], k[2], exec_cmd(panel .. k[3]), k[4], { locked = true, repeating = k[5] })
end

rebind("ALT", "F4", dispatch("killactive", ""), "close active window")
rebind("SUPER", "L", exec_cmd("$HOME/.config/hypr/scripts/LockScreen.sh"), "lock screen")

-- Alt-Tab, as in GNOME: a tap goes straight to the previous window (Alt-Shift-Tab: the least recent one).
-- Keep Alt held and press Tab again for the list of every window, most recently used first; release Alt to pick.
-- Between the two Hyprland sits in submap dotfiles-alttab (releasing Alt leaves it); while the list is up, in the
-- empty dotfiles-switch, so Tab reaches rofi instead of a bind (the script leaves it when rofi closes).
-- Super-Escape gets out of either if that ever fails.
local function by_recency()
  local list = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped then list[#list + 1] = w end
  end
  table.sort(list, function(a, b) return (a.focus_history_id or 0) < (b.focus_history_id or 0) end)
  return list
end
local function focus_window(w)
  if w.workspace and w.workspace.name == "special:minimized" then
    local cur = hl.get_active_workspace()
    if cur then hl.dispatch(hl.dsp.window.move({ window = w, workspace = tostring(cur.id), follow = false })) end
    hl.exec_cmd("pkill -RTMIN+11 -x waybar")
  end
  hl.dispatch(hl.dsp.focus({ window = w }))
  hl.dispatch(hl.dsp.window.bring_to_top())
end
local function quick_switch(backward)
  return function()
    local list = by_recency()
    if #list > 1 then focus_window(backward and list[#list] or list[2]) end
    hl.dispatch(hl.dsp.submap("dotfiles-alttab"))
  end
end
local function open_list(direction)
  return function()
    hl.dispatch(hl.dsp.submap("dotfiles-switch"))
    hl.exec_cmd(windows .. " switch " .. direction)
  end
end
hl.define_submap("dotfiles-alttab", function()
  bind("ALT", "Tab", open_list("next"), { description = "window list" })
  bind("ALT SHIFT", "Tab", open_list("prev"), { description = "window list, backward" })
  hl.bind("ALT + Alt_L", hl.dsp.submap("reset"), { release = true, description = "Alt released: done switching" })
  hl.bind("ALT + Alt_R", hl.dsp.submap("reset"), { release = true, description = "Alt released: done switching" })
  bind("SUPER", "Escape", hl.dsp.submap("reset"), { description = "leave the window switcher" })
end)
hl.define_submap("dotfiles-switch", function()
  bind("SUPER", "Escape", hl.dsp.submap("reset"), { description = "leave the window switcher" })
end)
if use_hyprshell then
  unbind("ALT", "Tab")
  unbind("ALT SHIFT", "Tab")
else
  rebind("ALT", "Tab", quick_switch(false), "switch to the previous window")
  rebind("ALT SHIFT", "Tab", quick_switch(true), "switch to the least recent window")
end

-- ---------------------------------------------------------------- minimize
-- Minimized windows wait in special:minimized. Super-U: menu to bring one back (to the current workspace);
-- the waybar module (custom/minimized) shows how many there are. Super-Shift-U minimizes.
rebind("SUPER SHIFT", "U", exec_cmd(windows .. " minimize"), "minimize window")
rebind("SUPER", "U", exec_cmd(windows .. " restore"), "restore a minimized window")
-- An app's own minimize button (GTK and Firefox title bars) asks the compositor; Hyprland ignores it by default
hl.on("window.minimize", function(win, minimize)
  if win and minimize ~= false and minimize ~= 0 then
    hl.dispatch(hl.dsp.window.move({ window = win, workspace = "special:minimized", follow = false }))
    hl.exec_cmd("pkill -RTMIN+11 -x waybar")
  end
end)
-- Focusing a minimized window from anywhere (hyprshell's Alt-Tab and overview list them too) restores it, like
-- GNOME. Otherwise Hyprland shows special:minimized over the desktop, dimmed, and new windows open into it.
hl.on("window.active", function(win)
  if not (win and win.workspace and win.workspace.name == "special:minimized") then return end
  local cur = hl.get_active_workspace()
  if not cur or cur.special then return end
  hl.dispatch(hl.dsp.window.move({ window = win, workspace = tostring(cur.id), follow = false }))
  local shown = hl.get_active_special_workspace()
  if shown and shown.name == "special:minimized" then hl.dispatch(hl.dsp.workspace.toggle_special("minimized")) end
  hl.dispatch(hl.dsp.focus({ window = win }))
  hl.exec_cmd("pkill -RTMIN+11 -x waybar")
end)

-- ---------------------------------------------------------------- behavior
-- Applied once the whole config has loaded (this event comes after it, the first load too):
-- user_settings.lua is read after this file and sets follow_mouse. (hl.timer would crash --verify-config.)
hl.on("config.reloaded", function()
  hl.config({
    input = { follow_mouse = 2 },             -- click to focus (hovering only aims the scroll wheel)
    misc = { focus_on_activate = true },      -- an app asking for focus gets it (a link opened in the browser)
  })
end)

-- Workspace 10 is a regular desktop: windows opened there float
hl.window_rule({ name = "dotfiles-floating-workspace", match = { workspace = "10" }, float = true })

hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpm reload -n")  -- plugins (hyprbars); the config is read again once they're loaded
  -- The desktop setup's dock (Ctrl-Alt-D toggles it). Not `Dock.sh --start` alone: it takes any process whose command
  -- line mentions the dock (e.g. another script's `pgrep -f` at login) for a running dock, and then starts none.
  -- So once startup has settled, by process name (cut to 15 characters), and --restart starts it regardless.
  hl.exec_cmd("sh -c 'sleep 3; pgrep -x nwg-dock-hyprla >/dev/null || exec " .. hypr .. "/scripts/Dock.sh --restart'")
  if have("/usr/bin/fcitx5") then hl.exec_cmd("fcitx5 -d --replace") end
  if use_hyprshell then hl.exec_cmd(hyprshell .. " -c " .. hyprshell_conf .. " run") end
  -- kanshi (packages.yaml): monitor profiles for docking, applied over the wlr-output-management protocol, so they
  -- override monitors.lua while it runs. Only with this machine's own profiles (untracked; see docs/layout.md)
  if have("/usr/bin/kanshi") and have(home .. "/.config/kanshi/config") then hl.exec_cmd("kanshi") end
  -- wayle in place of waybar + swaync, when chosen with dotfiles-panel.sh (linux/hypr/panel.sh)
  hl.exec_cmd(hypr .. "/dotfiles-panel.sh login")
end)

-- ~/.local/bin (wayle, hyprshell, vicinae and the like from packages.yaml) on the PATH of everything Hyprland starts:
-- a session from the login screen doesn't get it (no login shell runs), so e.g. wayle's buttons that call `wayle`
-- did nothing
do
  local path, bin = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin", home .. "/.local/bin"
  if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then hl.env("PATH", bin .. ":" .. path) end
end

-- Japanese input: fcitx5 with Mozc (packages.yaml); Ctrl-Space switches. GNOME keeps ibus (Super-Space).
if have("/usr/bin/fcitx5") then
  hl.env("XMODIFIERS", "@im=fcitx")
  hl.env("QT_IM_MODULE", "fcitx")
  hl.env("SDL_IM_MODULE", "fcitx")
end

-- ---------------------------------------------------------------- focus flash
-- hyprfocus plugin (packages.yaml): a short flash on the window that gets focus from the keyboard (Alt-Tab,
-- workspace keys), so it's clear where you landed; not on clicks. Its defaults do just that, so nothing is set here.
-- To change it: hl.config({ plugin = { hyprfocus = { keyboard_focus_animation = "flash" | "shrink" | "slide" | "none",
-- mouse_focus_animation = ..., fade_opacity = 0.8 } } }). (It has no hl.plugin.hyprfocus table to test for.)

-- ---------------------------------------------------------------- title bars
-- minimize/maximize/close (hyprbars plugin, from packages.yaml)
local bars = hl.plugin and hl.plugin.hyprbars
if bars then
  hl.config({
    plugin = {
      hyprbars = {
        bar_height = 24,
        bar_color = "rgb(1e1e2e)",
        ["col.text"] = "rgb(cdd6f4)",
        bar_text_size = 10,
        bar_text_font = "JetBrainsMono Nerd Font",
        bar_part_of_window = true,
        bar_precedence_over_border = true,
        bar_padding = 10,
        bar_button_padding = 8,
        on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
      },
    },
  })
  -- Listed right to left
  bars.add_button({
    bg_color = "rgb(f38ba8)", fg_color = "rgb(1e1e2e)", size = 14, icon = "✕",
    action = [[hyprctl dispatch 'hl.dsp.window.close()']],
  })
  bars.add_button({
    bg_color = "rgb(a6e3a1)", fg_color = "rgb(1e1e2e)", size = 14, icon = "□",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
  })
  bars.add_button({
    bg_color = "rgb(f9e2af)", fg_color = "rgb(1e1e2e)", size = 14, icon = "–",
    action = windows .. " minimize",
  })
end
