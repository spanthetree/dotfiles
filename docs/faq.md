# FAQ

**What does it change on my machine?**
It symlinks configs into `~` (list in [layout](layout.md)), clones a few plugins, and with `--packages` installs the tools in [software](software.md). Under WSL it also merges a theme into Windows Terminal, sets mirrored networking in `.wslconfig`, and installs the Windows apps. Anything it replaces is moved to `~/.dotfiles-backup/<timestamp>/`. Nothing is deleted.

**I don't like it. How do I undo it?**
`install.cmd --uninstall`, on Linux, in WSL, or on Windows (see [install](install.md#uninstall)). It removes the links, plugins and settings, and puts back what was there before the first install. It also uninstalls the packages it installed (it asks first; `--yes` skips the question). Packages that were already on the machine stay. Your default shell stays zsh: `chsh -s /bin/bash` to change it. Then delete the clone. On Windows, add `--remove-wsl` to also delete the WSL distro(s) with the repo, and WSL itself if nothing else uses it. Backups stay in `~/.dotfiles-backup`.

**Does it work on native Linux, not just WSL?**
Yes. `./install.cmd` works the same. Steps for WSL and Windows are skipped. `--packages` needs Debian or Ubuntu (apt). On other distros, the configs still install. Install the tools you want by hand from [software](software.md).

**macOS?**
Not supported. The configs mostly work, but `--packages` needs apt.

**If I run it inside WSL, does it set up Windows too?**
Yes. From WSL it installs the Windows apps with winget, merges the Windows Terminal theme, sets `.wslconfig`, and sets up YASB (config in `%USERPROFILE%\.config\yasb`, autostart on). Only installing WSL itself needs the Windows side (`install.cmd` from Windows, or the PowerShell one-liner in [install](install.md)). With a Windows clone, YASB reads its config straight from that clone instead.

**Why `install.cmd` on Linux?**
It's one file that works as both a Windows batch file and a shell script. On Linux, `./install.cmd` (or `sh install.cmd`) runs `linux/install.sh`. On Windows, `install.cmd` runs `windows\install.ps1`.

**Why does it ask for my sudo password at the start?**
Steps run behind spinners, where a sudo prompt would be hidden. It asks once and keeps it fresh for the run.

**A step failed. Where's the output?**
A failed step prints its last 20 lines. For everything, run it with `--no-fx`.

**How do I update?**
`git -C ~/dotfiles pull && ~/dotfiles/install.cmd --packages`. Each run also upgrades apt packages and the GitHub-release tools.

**How do I add or remove a tool?**
Edit [`packages.yaml`](../packages.yaml) and re-run with `--packages`. See [packages](packages.md).

**Where do my own settings and secrets go?**
`~/.zshrc.local` for machine-only settings, `~/.zsh_secrets.gpg` for tokens. Neither is committed. See [install](install.md#per-machine-files-never-committed).

**Byobu starts in every terminal. How do I stop that?**
`touch ~/.config/byobu/disable-autolaunch`.

**An app's shortcut doesn't work inside byobu.**
Byobu takes some keys first. See [hotkeys: clashes](hotkeys.md#clashes).

**Why does `Ctrl-S` save my tabs instead of freezing the terminal?**
Byobu binds it to save tabs. vim, nano and Claude Code still get it.

**I see boxes instead of icons.**
Your terminal needs a Nerd Font. The Windows installer installs JetBrainsMono Nerd Font and Windows Terminal uses it. Elsewhere, install one from https://www.nerdfonts.com and select it in your terminal.

**Can I contribute?**
Only verified bug fixes and interface improvements. For anything else, fork it. See the [README](../README.md#contributing).
