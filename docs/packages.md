# Packages

[`packages.yaml`](../packages.yaml) is the one list for both systems: `linux:` (apt, apt repos, GitHub releases, install scripts) and `windows:` (winget ids). Its keys are documented at the top of the file.

- **Add:** add a line, re-run `install.cmd --packages`.
- **Remove:** delete its line and re-run. The installer asks, then uninstalls it, but only if it installed it on that machine (recorded in `~/.local/state/dotfiles/linux.json` and `%LOCALAPPDATA%\dotfiles\windows.installed`).
- **Existing machine:** run `install.cmd --packages --adopt` once, so what's already installed counts as managed.
- **Language tools:** list them under their language's entry as `tools:` (go: `go install`, pyenv: `uv tool install`, rbenv: `gem install`). They install after the language and leave with it.
- **Updates:** each run upgrades apt packages (`settings.upgrade`) and re-downloads GitHub binaries in `~/.local/bin` when a newer release is out.

Core packages (git, curl, zsh, python3...) are never removed. `settings.autoremove` also clears leftover apt dependencies.

## Highlights

| Area | Tools |
|---|---|
| Modern CLI | eza, bat, fd, ripgrep, zoxide, fzf, sd, dust, duf, gdu, procs, btop, yazi, broot, jless, fx, difftastic, delta, viddy, watchexec, hyperfine |
| Network | nmap, tshark, termshark, mtr (`mtrr` report alias), gping, doggo, bandwhich, bgpq4, iperf3, xh/`ht` |
| Kubernetes / cloud | kubectl, kubectx, k9s, stern, helm, terraform, ansible, Docker, AWS CLI |
| Languages | pyenv with Python 3.11/3.12 (global)/3.14, uv, rbenv with Ruby 3.2/3.4 (global)/4.0, Go (latest, plus gopls), nvm |
| AI CLIs | Claude Code, Codex, OpenCode |
| Windows | Windows Terminal, VS Code, YASB, PowerToys, Sysinternals (Microsoft Store), Everything, Wireshark, Nmap |
