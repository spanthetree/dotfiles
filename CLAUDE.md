# CLAUDE.md

Notes for AI agents working on this repo: rules and lessons the code doesn't show. Layout and usage are in [docs/](docs/).

## Rules

- **Public repo.** Before every commit, check new content for personal data: names, emails, hostnames, IPs, employers, tokens. Machine-specific things belong in untracked per-machine files (`~/.zshrc.local`, `~/.zsh_secrets.gpg`), never in the repo. That includes proxies and NAS mounts.
- **Commit or push only when the owner says so** ("push"). Commits use the `spanthetree <spanthetree@users.noreply.github.com>` identity.
- **Contributions:** only verified bug fixes and interface improvements are accepted; everything else is for forks (README).
- **Every change goes through `packages.yaml` or the installers.** Nothing is set up by hand on one machine only, and every change must also be undone by `install.cmd --uninstall`. If you add a link, add it to `LINKS` in `linux/install.sh`. If you add a system change, add its undo to `uninstall_system`.

## Releasing

Semver: new feature = minor, fix = patch, a change that needs manual steps on existing machines = major (for example moving linked files: existing symlinks dangle until the installer re-runs).

1. Add a `## [X.Y.Z] - date` section to `CHANGELOG.md` (Keep a Changelog), plus its compare link at the bottom.
2. Commit, then `git tag -a vX.Y.Z -m vX.Y.Z && git push -q && git push -q --tags`.
3. Write the section to a notes file and run `gh release create vX.Y.Z --title vX.Y.Z --notes-file <notes> --verify-tag --latest`:
   `awk '/^## \[X.Y.Z\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md >| notes.md`

## Testing

- **tmux/byobu changes:** use an isolated server so the owner's sessions are untouched: `tmux -L test new -d -x 120 -y 30 '...'`, then `tmux -L test capture-pane -p`. To see a popup or the status bar, run an inner client inside an outer `-L` server and capture the outer one.
- **Live tmux edits:** zsh can't parse tmux `{ }` blocks on the command line. Put the lines in a file and `tmux source-file` it.
- **Installer and packages:** test in a clean `ubuntu:24.04` container with a cut-down `packages.yaml` (install, then `--uninstall --yes`), not on the owner's machine. A container on a WSL host still reports WSL in `/proc/version`, so `is_wsl` is true there.
- **Checks:** `python3 -I windows/terminal/test_merge.py`; from WSL: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w windows/test_install.ps1)"`.
- `install.cmd` must parse in both `cmd.exe` and `sh`. Keep it LF-only (`.gitattributes`) and keep the `:;` line first.

## Gotchas

- **Python:** `packages.py` must run under `/usr/bin/python3 -I`. pyenv's python has no PyYAML.
- **Python /dev/tty:** don't open `/dev/tty` with `'r+'`. In text mode it raises "not seekable" (an OSError). Use separate read and write handles.
- **fzf is 0.44** (Ubuntu 24.04 apt). Don't use newer fzf options. `--listen`, `transform-prompt` and `change:reload` work.
- **Shell field splitting:** `read` with a tab IFS merges empty fields. Use `cut -f`/awk for tmux format output with possibly empty fields.
- **tmux status list:** `#[list=focus]` only works when `#[list=on]` follows the focused item.
- **tmux prompts:** inside `confirm-before`, `Ctrl-W` is delete-word. That's why "Ctrl-W twice closes" uses a key table (`close-tab`).
- **tmux-continuum's auto-restore** skips when several Windows Terminal tabs start byobu at once. `bin/restore-tabs` replaces it: it renames byobu's startup session to the saved one, so restore goes into it with no stray session.
- **Keys taken outside tmux:** `Alt-R` is taken by the NVIDIA overlay on the owner's machine, so rename in the Alt-D popup is `F8`. Check new global keys against [docs/hotkeys.md](docs/hotkeys.md#clashes).
- **winget `Microsoft.Sysinternals.Suite`** fails its hash check whenever Microsoft updates the unversioned zip. Use the Store id `9P7KNL5RWT25`.
- **WSL mirrored networking:** NFS mounts need `noresvport`, or mounting hangs and WSL starts slowly.
- **The owner's zsh** has `noclobber`: overwrite with `>|`.
- **Claude Code's safety check** blocks `rm` inside `bash -c`. Put the `rm` in a script file, as `command rm` (the plain `rm` alias is interactive).

## Decisions already made (don't re-propose)

- **byobu stays.** zellij was compared and rejected.
- **No atuin.**
- **trippy was dropped.** Its report mode lacks AS data and its DNS was slow. Use mtr (`mtrr` alias).
- **NextTrace is skipped.** It sends hop IPs to its own API by default.
- **No proxy settings in the repo.** They are per-machine.
- **The installer has no animations beyond the typed title.** The pegasus was removed. Spinners stay, because they show progress.
