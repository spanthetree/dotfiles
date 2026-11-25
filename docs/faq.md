# FAQ

**What does it change on my machine?**
It symlinks configs into `~` (list in [layout](layout.md)), clones a few plugins, installs the tools in [software](software.md). Under WSL it also merges a theme into Windows Terminal, sets mirrored networking in `.wslconfig`, and installs the Windows apps. On a Linux desktop it also sets up kitty, Japanese input, and its layer on Hyprland or COSMIC where they are installed (see [install](install.md#linux--wsl)). Anything it replaces is moved to `~/.dotfiles-backup/<timestamp>/`. Nothing is deleted.

**I don't like it. How do I undo it?**
`install.cmd --uninstall`, on Linux, in WSL, or on Windows (see [install](install.md#uninstall)). It removes the links, plugins and settings, and puts back what was there before the first install. It also uninstalls the packages it installed (it asks first; `--yes` skips the question). Packages that were already on the machine stay. Your default shell stays zsh: `chsh -s /bin/bash` to change it. Then delete the clone. On Windows, add `--remove-wsl` to also delete the WSL distro(s) with the repo, and WSL itself if nothing else uses it. Backups stay in `~/.dotfiles-backup`.

**Does it work on native Linux, not just WSL?**
Yes. `./install.cmd` works the same. Steps for WSL and Windows are skipped. Installing packages needs Debian or Ubuntu (apt). On other distros, the configs still install. Install the tools you want by hand from [software](software.md).

**Can I try Hyprland or COSMIC?**
On Ubuntu with a desktop: `install.cmd --hyprland` (Ubuntu 26.04+) or `install.cmd --cosmic`, then pick it at the login screen. Both get the same keys and SynthWave '84 look. `--no-hyprland` / `--no-cosmic` remove them again. See [install](install.md#hyprland).

**macOS?**
Not supported. The configs mostly work, but installing packages needs apt.

**If I run it inside WSL, does it set up Windows too?**
Yes. From WSL it installs the Windows apps with winget, merges the Windows Terminal theme, sets `.wslconfig`, and sets up YASB (config in `%USERPROFILE%\.config\yasb`, autostart on). Only installing WSL itself needs the Windows side (`install.cmd` from Windows, or the PowerShell one-liner in [install](install.md)). With a Windows clone, YASB reads its config straight from that clone instead.

**Why `install.cmd` on Linux?**
It's one file that works as both a Windows batch file and a shell script. On Linux, `./install.cmd` (or `sh install.cmd`) runs `linux/install.sh`. On Windows, `install.cmd` runs `windows\install.ps1`.

**Why does it ask for my sudo password at the start?**
Steps run behind spinners, where a sudo prompt would be hidden. It asks once and keeps it fresh for the run.

**A step failed. Where's the output?**
A failed step prints its last 20 lines. For everything, run it with `--no-fx`.

**How do I update?**
`git -C ~/dotfiles pull && ~/dotfiles/install.cmd`. Each run also upgrades apt packages and the GitHub-release tools.

**How do I add or remove a tool?**
Edit [`packages.yaml`](../packages.yaml) and re-run `install.cmd`. See [packages](packages.md).

**Does this machine still match the repo?**
`install.cmd --check` lists what differs (links, packages a run would install or uninstall, settings) and changes nothing. A re-run of `install.cmd` fixes most of it.

**How do I use another Python, Ruby or Go version?**
They come from mise. `mise use -g python@3.13` changes the global one; in a project, `mise use python@3.11` (writes `mise.toml`), or a `.python-version` / `.ruby-version` file. `mise ls` shows what's installed. pyenv and rbenv are no longer used.

**Why wasn't Beeper installed?**
Before installing it, the installer looks for software that can read the machine's files or record its screen (endpoint security, DLP, screen monitoring, as on many work machines). If it finds some, it names it and asks; no, `--yes` and a run with no terminal all mean it isn't installed. The answer is remembered until what's found changes. See [packages](packages.md).

**My commit was stopped by a "privacy check".**
This repo is public, so its pre-commit hook stops commits that add secrets, email addresses, or anything matching your own patterns in `~/.config/dotfiles/private-patterns`. Fix the lines it shows; if they're fine, `git commit --no-verify`. See [development](development.md#privacy-check-before-commits).

**How do I keep an SSH tunnel up?**
`tun bastion -D 1080` (or `-L` / `-R`, as with ssh). It reconnects by itself after a dropped link; Ctrl-C stops it. See [install: SSH](install.md#ssh).

**My SSH session froze when the network dropped.**
The shared SSH settings end a dead connection within about 90 seconds, instead of leaving it frozen. For a long-lived session, run byobu on the far end and reattach.

**Where do my own settings and secrets go?**
`~/.zshrc.local` for machine-only settings, `~/.zsh_secrets.gpg` for tokens. Neither is committed. See [install](install.md#per-machine-files-never-committed).

**Byobu starts in every terminal. How do I stop that?**
`touch ~/.config/byobu/disable-autolaunch`.

**An app's shortcut doesn't work inside byobu.**
Byobu takes some keys first. See [hotkeys: clashes](hotkeys.md#clashes).

**Why does `Ctrl-S` save my tabs instead of freezing the terminal?**
Byobu binds it to save tabs. vim, nano and Claude Code still get it.

**I see boxes instead of icons.**
Your terminal needs a Nerd Font. The Windows installer installs JetBrainsMono Nerd Font and Windows Terminal uses it. On a Linux desktop the installer adds the JetBrainsMono, FantasqueSansM, Departure Mono and Terminess Nerd Fonts, and kitty uses Departure Mono. Elsewhere, install one from https://www.nerdfonts.com and select it in your terminal.

**Can I contribute?**
Only verified bug fixes and interface improvements. For anything else, fork it. See the [README](../README.md#contributing).
