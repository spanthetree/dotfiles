# Install

`install.cmd` in the repo root is the installer for both systems. It is a Windows batch file and a shell script in one: on Linux or WSL it runs `linux/install.sh`, on Windows `windows\install.ps1`.

## Linux / WSL

Native Linux or WSL. `--packages` needs Debian/Ubuntu (apt); on other distros only the configs install.

```sh
gh repo clone spanthetree/dotfiles ~/dotfiles
~/dotfiles/install.cmd --packages   # first time: also installs tools (Debian/Ubuntu)
~/dotfiles/install.cmd              # later: just re-link configs
```

Configs are symlinked, so editing `~/.zshrc` etc. edits this repo. Anything already in the way is moved to `~/.dotfiles-backup/<timestamp>/`, never deleted. Re-running is safe.

Update a machine: `git -C ~/dotfiles pull && ~/dotfiles/install.cmd`

| Option | Does |
|---|---|
| `--packages` | also install missing tools from [`packages.yaml`](../packages.yaml), uninstall removed ones (see [packages](packages.md)) |
| `--adopt` | once per existing machine: treat everything from `packages.yaml` already installed as managed |
| `--yes` | uninstall removed packages without asking |
| `--uninstall` | remove it all (below) |
| `--no-fx` | plain output with each step's full output (also `NO_FX=1`; the default when output isn't a terminal) |

Output: themed section headers, and a spinner with elapsed time on each step (`✓`/`✗` when done; a failed step shows its last 20 lines). With `--packages`, sudo asks once at the start and stays fresh for the run.

Under WSL it also:
- merges the SynthWave '84 scheme and defaults into Windows Terminal's `settings.json` (backup first)
- sets `networkingMode=mirrored` in `%USERPROFILE%\.wslconfig`: WSL shares Windows' network interfaces, so nmap/tcpdump see the real LAN. Apply with `wsl --shutdown`
- installs the `windows:` apps with winget
- puts the YASB config in `%USERPROFILE%\.config\yasb` and turns on YASB's autostart, unless a Windows clone already manages it (`YASB_CONFIG_HOME`)

On every system it points git's pager at delta via `include.path` to `linux/git/delta.gitconfig`.

## New Windows machine

From any PowerShell window:

```powershell
irm https://raw.githubusercontent.com/spanthetree/dotfiles/main/windows/install.ps1 -OutFile $env:TEMP\dotfiles.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\dotfiles.ps1
```

It asks for admin, then:
1. Installs the `windows:` apps from `packages.yaml` with winget: Windows Terminal, VS Code, Git, YASB, Claude Desktop, OpenCode Desktop, PowerToys, Sysinternals, Everything, Wireshark, Nmap and JetBrainsMono Nerd Font. Wireshark/Nmap may show the Npcap setup window: click through it.
2. Clones this repo to `%USERPROFILE%\dotfiles` and points YASB at `windows\yasb` (`YASB_CONFIG_HOME`), with autostart on.
3. Asks which Debian/Ubuntu distro to install, enables WSL2 (reboots once if needed and resumes after sign-in), and installs the distro. Create your Linux user, then type `exit`.
4. Inside WSL, clones this repo to `~/dotfiles` and runs `install.cmd --packages`.

With the repo already cloned on Windows, `install.cmd` from it does the same.

The script installs the `powershell-yaml` module (current user) to read `packages.yaml`. Re-running is safe. Two clones exist: Windows (YASB config) and WSL (everything else).

## Uninstall

```sh
~/dotfiles/install.cmd --uninstall   # add --yes to skip the questions
```

On Windows, `install.cmd --uninstall` runs this inside every WSL distro that has `~/dotfiles`. Then it turns off YASB's autostart, clears `YASB_CONFIG_HOME`, and uninstalls any Windows apps still recorded (it asks). WSL and its distros stay: `wsl --unregister <name>` deletes one, with all its files.

On Linux or in WSL it:
1. Uninstalls the packages this installer installed (it lists them and asks), and the apt repos it added. Under WSL, also the Windows apps it installed. Packages that were already there stay, and so do core ones (git, curl, zsh, python3...).
2. Removes the config links and the plugins it cloned (antidote, tmux-resurrect, tmux-continuum, vim-plug and vim plugins).
3. Puts back what the links replaced, from the oldest backup (from before the first install).
4. Removes the delta include from `~/.gitconfig`. Under WSL, it restores Windows Terminal's settings, `.wslconfig` and the YASB config from before the first install (today's Windows Terminal settings are backed up first), clears `YASB_CONFIG_HOME` and turns off YASB's autostart.

Left for you: `chsh -s /bin/bash` if you want another shell, and deleting the clone(s). Backups stay in `~/.dotfiles-backup`.

## Per-machine files (never committed)

| File | For |
|---|---|
| `~/.zshrc.local` | kube contexts, machine-only aliases |
| `~/.zsh_secrets.gpg` | tokens; decrypted and sourced at shell start |
| `~/.config/byobu/disable-autolaunch` | touch it to stop byobu auto-starting |

## VS Code

`install.cmd --packages` installs it (Windows host under WSL; Linux only with a desktop). Settings, extensions, keybindings and theme come from VS Code Settings Sync: sign in with GitHub. WSL extensions install automatically from the `remote.defaultExtensionsIfInstalledLocally` list in synced settings.
