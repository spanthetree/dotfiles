# Install

`install.cmd` in the repo root is the installer for both systems. It is a Windows batch file and a shell script in one: on Linux or WSL it runs `linux/install.sh`, on Windows `windows\install.ps1`.

## Linux / WSL

Native Linux or WSL. Installing packages needs Debian/Ubuntu (apt); on other distros only the configs install.

```sh
gh repo clone spanthetree/dotfiles ~/dotfiles
~/dotfiles/install.cmd               # installs tools (Debian/Ubuntu) and links configs
~/dotfiles/install.cmd --no-packages # configs only
```

Configs are symlinked, so editing `~/.zshrc` etc. edits this repo. Anything already in the way is moved to `~/.dotfiles-backup/<timestamp>/`, never deleted. Re-running is safe.

Update a machine: `git -C ~/dotfiles pull && ~/dotfiles/install.cmd`

| Option | Does |
|---|---|
| `--no-packages` | configs only: skip installing missing tools from [`packages.yaml`](../packages.yaml) and uninstalling removed ones (see [packages](packages.md)) |
| `--adopt` | once per existing machine: treat everything from `packages.yaml` already installed as managed |
| `--yes` | uninstall removed packages without asking |
| `--cosmic` | also install the [COSMIC](https://system76.com/cosmic) desktop, picked at the login screen next to GNOME and Hyprland (see [COSMIC](#cosmic)). Remembered on this machine; `--no-cosmic` drops it and offers to uninstall it |
| `--hyprland` | also install the Hyprland desktop setup (Ubuntu 26.04+; see [Hyprland](#hyprland)), picked at the login screen. Remembered on this machine; `--no-hyprland` drops it and offers to uninstall it. On a machine where it's already installed: `--hyprland --adopt` once |
| `--uninstall` | remove it all (below) |
| `--no-fx` | plain output with each step's full output (also `NO_FX=1`; the default when output isn't a terminal) |
| `--check` | change nothing: list what differs from the repo (missing or replaced links, packages a run would install or uninstall, COSMIC settings changed in Settings, the repo's commit hook); exits 1 if anything does. Linux and WSL (from WSL it also checks the Windows apps) |

Output: themed section headers, and a spinner with elapsed time on each step (`✓`/`✗` when done; a failed step shows its last 20 lines). When it installs packages, sudo asks once at the start and stays fresh for the run.

Under WSL it also:
- merges the SynthWave '84 scheme and defaults into Windows Terminal's `settings.json` (backup first)
- sets `networkingMode=mirrored` in `%USERPROFILE%\.wslconfig`: WSL shares Windows' network interfaces, so nmap/tcpdump see the real LAN. Apply with `wsl --shutdown`
- installs the `windows:` apps with winget
- puts the YASB config in `%USERPROFILE%\.config\yasb` and turns on YASB's autostart, unless a Windows clone already manages it (`YASB_CONFIG_HOME`)

On a Linux desktop (not WSL) it also:
- installs kitty with this repo's config (`linux/kitty`: SynthWave '84, Departure Mono Nerd Font, byobu's keys), the JetBrainsMono, FantasqueSansM, Departure Mono and Terminess Nerd Fonts, VS Code, Spotify, and slurp for screen recording
- installs Beeper, unless software that could read its chats is found: then it asks first (see [packages](packages.md))
- sets up Japanese input with `Ctrl-Space`: ibus + Mozc on GNOME (the input-source switch moves there from `Super-Space`), fcitx5 + Mozc under Hyprland and COSMIC
- adds this repo's layer to Hyprland wherever Hyprland is installed (below), however it got there

On every system it points git's pager at delta via `include.path` to `linux/git/delta.gitconfig`, and turns on this repo's privacy check before commits (`core.hooksPath` in the clone; see [development](development.md#privacy-check-before-commits)). Python, Ruby and Go versions come from mise (`mise use -g python@3.13` changes the global one; `.python-version`, `.ruby-version` and `mise.toml` set one per project).

## Hyprland

`install.cmd --hyprland` (Ubuntu 26.04+) installs [LinuxBeginnings/Ubuntu-Hyprland](https://github.com/LinuxBeginnings/Ubuntu-Hyprland) (branch `26.04`): Hyprland from its PPA with waybar, rofi, swaync, hyprlock and the rest, and its Hyprland config [Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots). Both are pinned in `packages.yaml` (the `hyprland-desktop` entry), and this repo's Hyprland layer goes on top: `linux/hypr/dotfiles.lua`, hyprbars, hyprfocus, Hyprspace, hyprshell, wayle, kanshi and fcitx5. GDM stays the login screen. Log in to Hyprland and run the installer once more from there: the hyprpm plugins (hyprbars, hyprfocus, Hyprspace) are only built from inside a running Hyprland.

It asks a few questions as it goes: its installer's checklist opens with [`linux/hypr/preset.sh`](../linux/hypr/preset.sh) ticked (its GTK themes, Thunar and Bluetooth; not its SDDM, zsh or AGS overview; NVIDIA setup only where there is an NVIDIA GPU), and its config asks about screen resolution, clock and the like. When the pinned config version moves ahead of the installed one, the next run upgrades it (`copy.sh --express-upgrade`, a few questions again). `--no-hyprland` and `--uninstall` run its own uninstaller, told to leave what this repo also installs (kitty, btop, slurp, `~/.config/kitty`).

The layer works with a Hyprland installed some other way too: its packages (`when: in-hyprland`) install and update on a run from inside a Hyprland session, or wherever `--hyprland` was chosen. From GNOME or COSMIC they are skipped, and stay installed. Its services (hypridle, hyprpaper, swaync) start only in a Hyprland session (`linux/hypr/hyprland-only.conf`), not in GNOME or COSMIC.

## COSMIC

`install.cmd --cosmic` adds System76's COSMIC desktop as a second choice at the login screen. Ubuntu doesn't package it, so it comes from the community PPA [hepp3n/cosmic-epoch](https://launchpad.net/~hepp3n/+archive/ubuntu/cosmic-epoch) (not System76's: report COSMIC-on-Ubuntu bugs there). It brings its own panel, dock, launcher, Alt-Tab, workspace overview and title bars, so the Hyprland additions don't apply to it; it gets the same keys and look instead. From this repo it gets:

- the Hyprland setup's keys, where COSMIC has the action (`linux/cosmic/shortcuts.ron`, listed in [hotkeys](hotkeys.md#cosmic-linuxcosmicshortcutsron-with-installcmd---cosmic))
- tiling on for every workspace, and workspaces side by side (`Super-Y` turns tiling off for one workspace)
- the SynthWave '84 theme with frosted glass (`linux/cosmic/SynthWave-84.ron`), imported by the installer whenever it changes
- `Ctrl-Alt-Shift-R` / `Ctrl-Alt-Shift-A` screen recording (with wl-screenrec, built with cargo)
- Japanese input: fcitx5 + Mozc, `Ctrl-Space`, as under Hyprland (started by `linux/cosmic/fcitx5.desktop`; its environment in `linux/zsh/zprofile`), with `EN` / `あ` in the panel from this repo's own applet (`linux/cosmic/input-applet`; click switches, right click opens fcitx5's settings)
- `Alt-Tab` with live window previews: [pivot](https://github.com/Sigma-studios/pivot), built with cargo at a pinned commit (early software; COSMIC's own switcher while it's missing)
- in the panel: a system monitor ([sysmon](https://github.com/leonardo-panseri/cosmic-ext-applet-sysmon), built with cargo at a pinned commit; numbers in the panel, graphs in its popup, right click opens btop) and keep-awake ([Caffeine](https://github.com/Oussamaberchi/caffeine-cosmic), built with cargo), placed like wayle's on Hyprland
- a wallpaper picker on `Super-W` with a built-in [Wallhaven](https://wallhaven.cc) browser that downloads and applies: [skwd-wall](https://github.com/liixini/skwd-wall), from its release's .debs at a pinned version (beta; its Ubuntu packages are new). It draws the wallpaper itself (its `skwd-walld` service, started only with COSMIC's session) over COSMIC's own background. Its optional AI search models (~1 GB) aren't installed

Its settings are copied into `~/.config/cosmic`, not linked. A setting changed in COSMIC Settings afterwards is left alone, and the installer says so; delete the file and re-run to take the repo's again. `--uninstall` and `--no-cosmic` remove them again. kitty, byobu and the rest are there as on any desktop.

Not possible in COSMIC (late 2026): Hyprland's see-through inactive windows and blur behind every window. COSMIC has no per-window opacity, and blurs only behind apps that ask for it (`ext-background-effect`); kitty asks from 0.46 on, and Ubuntu 26.04 has 0.45.

Known issues (late 2026): fcitx5 can stop responding after the screen is locked and unlocked, and resets Caps Lock / Num Lock (cosmic-epoch [#3475](https://github.com/pop-os/cosmic-epoch/issues/3475), [#3966](https://github.com/pop-os/cosmic-epoch/issues/3966)). `install.cmd --no-cosmic` removes it again, PPA included.

## New Windows machine

From any PowerShell window:

```powershell
irm https://raw.githubusercontent.com/spanthetree/dotfiles/main/windows/install.ps1 -OutFile $env:TEMP\dotfiles.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\dotfiles.ps1
```

It asks for admin, then:
1. Installs the `windows:` apps from `packages.yaml` with winget: Windows Terminal, VS Code, Git, YASB, Claude Desktop, OpenCode Desktop, PowerToys, Sysinternals, Everything, Wireshark, Nmap and JetBrainsMono Nerd Font. Wireshark/Nmap may show the Npcap setup window: click through it.
2. Clones this repo to `%USERPROFILE%\dotfiles` and points YASB at `windows\yasb` (`YASB_CONFIG_HOME`), with autostart on. Adds a "Wallpapers" Start-menu shortcut (`Ctrl-Alt-W`) for `windows\wallpapers.ps1`, which searches Wallhaven and sets the wallpaper you click.
3. Asks which Debian/Ubuntu distro to install, enables WSL2 (reboots once if needed and resumes after sign-in), and installs the distro. Create your Linux user, then type `exit`.
4. Inside WSL, clones this repo to `~/dotfiles` and runs `install.cmd`.

With the repo already cloned on Windows, `install.cmd` from it does the same.

The script installs the `powershell-yaml` module (current user) to read `packages.yaml`. Re-running is safe. Two clones exist: Windows (YASB config) and WSL (everything else).

## Uninstall

```sh
~/dotfiles/install.cmd --uninstall   # add --yes to skip the questions
```

On Windows, `install.cmd --uninstall` runs this inside every WSL distro that has `~/dotfiles`. Then it turns off YASB's autostart, clears `YASB_CONFIG_HOME`, removes the Wallpapers shortcut (downloaded wallpapers stay), and uninstalls any Windows apps still recorded (it asks). WSL and its distros stay.

To remove WSL too: `install.cmd --uninstall --remove-wsl` (Windows only). After the steps above, it deletes each distro that has `~/dotfiles`, **with all its files** (it asks for each one, unless `--yes`). If no other distro is left, it also uninstalls WSL and turns off its Windows feature (reboot to finish). Virtual Machine Platform stays on, since Docker Desktop and others use it.

On Linux or in WSL it:
1. Uninstalls the packages this installer installed (it lists them and asks), and the apt repos it added. Under WSL, also the Windows apps it installed. Packages that were already there stay, and so do core ones (git, curl, zsh, python3...).
2. Removes the config links and the plugins it cloned (antidote, tmux-resurrect, tmux-continuum, vim-plug and vim plugins).
3. Puts back what the links replaced, from the oldest backup (from before the first install).
4. Removes the delta include from `~/.gitconfig` and turns the repo's pre-commit hook off. Under WSL, it restores Windows Terminal's settings, `.wslconfig` and the YASB config from before the first install (today's Windows Terminal settings are backed up first), clears `YASB_CONFIG_HOME` and turns off YASB's autostart. On a desktop it removes the kitty includes, the edits to the Hyprland desktop setup's files (each marked `// dotfiles` or `# dotfiles`), the COSMIC settings and theme (unless changed in COSMIC Settings since), and puts GNOME's input sources back.

Left for you: `chsh -s /bin/bash` if you want another shell, and deleting the clone(s). Backups stay in `~/.dotfiles-backup`.

## Per-machine files (never committed)

| File | For |
|---|---|
| `~/.zshrc.local` | kube contexts, machine-only aliases |
| `~/.config/joplin`, `~/.config/joplin-desktop` | Joplin notes and its sync target and login, set in each app (`joplin config sync.target`) |
| `~/.zsh_secrets.gpg` | tokens; decrypted and sourced at shell start |
| `~/.suzieq/inventory.yml` | devices for SuzieQ to poll (`sq-poller -I ~/.suzieq/inventory.yml`) |
| `~/.config/GeoIP.conf` | MaxMind account ID and license key for trippy's GeoIP data; written by the installer when you enter them |
| `~/.config/byobu/disable-autolaunch` | touch it to stop byobu auto-starting |
| `~/.config/mise/config.toml` | your global Python, Ruby and Go versions (`mise use -g`); the installer sets them only while none is set |
| `~/.config/dotfiles/private-patterns` | your own patterns for the pre-commit privacy check: name, email, hostnames, employer, internal domains (one regex per line) |
| `~/.local/state/dotfiles/private.json` | your answers to "install anyway?" for Beeper on a monitored machine (Windows: `%LOCALAPPDATA%\dotfiles\private.json`); delete to be asked again |

## VS Code

`install.cmd` installs it (Windows host under WSL; Linux only with a desktop). Settings, extensions, keybindings and theme come from VS Code Settings Sync: sign in with GitHub. WSL extensions install automatically from the `remote.defaultExtensionsIfInstalledLocally` list in synced settings.
