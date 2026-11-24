# Packages

[`packages.yaml`](../packages.yaml) is the one list for both systems: `linux:` (apt, apt repos, GitHub releases, install scripts) and `windows:` (winget ids). Its keys are documented at the top of the file.

- **Add:** add a line, re-run `install.cmd`.
- **Remove:** delete its line and re-run. The installer asks, then uninstalls it, but only if it installed it on that machine (recorded in `~/.local/state/dotfiles/linux.json` and `%LOCALAPPDATA%\dotfiles\windows.installed`).
- **Existing machine:** run `install.cmd --adopt` once, so what's already installed counts as managed.
- **Language tools:** list them under their language's entry as `tools:` (go: `go install`, pyenv: `uv tool install`, rbenv: `gem install`). They install after the language and leave with it.
- **Opt-in desktops:** entries with `when: hyprland` or `when: cosmic` install only on machines run with `--hyprland` / `--cosmic` (remembered per machine). `--no-hyprland` / `--no-cosmic` uninstalls them as if their lines were deleted. `when: in-hyprland` (the Hyprland layer) runs only from inside Hyprland or where `--hyprland` was chosen; elsewhere it's skipped, not removed.
- **Updates:** each run upgrades apt packages (`settings.upgrade`) and re-downloads GitHub binaries in `~/.local/bin` when a newer release is out.

Core packages (git, curl, zsh, python3...) are never removed. An apt package counts as installed by this repo only if apt has it as installed by hand, so a library already there as another package's dependency is never claimed. One that other installed packages still need is never removed: it stays as an ordinary dependency. Every apt removal is simulated first and refused if apt would take anything more, or anything essential or part of the desktop. `settings.autoremove` also clears the dependencies those removals left unneeded, nothing else.

## Highlights

| Area | Tools |
|---|---|
| Modern CLI | eza, bat, fd, ripgrep, zoxide, fzf, carapace, navi, tldr, sd, dust, duf, gdu, procs, btop, yazi, broot, fx, jaq, gron, jc, lnav, rare, VisiData, difftastic, delta, viddy, watchexec, hyperfine |
| Network | nmap, RustScan, tshark, termshark, mtr (`mtrr` report alias), trippy (`trip`), SuzieQ, gnmic, TTP + ntc-templates, asn, monocle, globalping, gping, doggo, rustnet, sshs, termscp, bgpq4, iperf3, xh, oha, eBPF (pwru, bpftrace, BCC) |
| Kubernetes / cloud | containerlab, kubectl + krew plugins, kubectx, k9s, stern, kubeshark, helm + helm-diff, helmfile, tenv (terraform/tofu), tflint, terraform-docs, infracost, steampipe, ansible, Docker, AWS CLI, granted |
| Languages | mise, pyenv with Python 3.11/3.12 (global)/3.14, uv, rbenv with Ruby 3.2/3.4 (global)/4.0, Go (latest, plus gopls), nvm |
| Notes | Joplin: terminal app, desktop app (Linux desktop, Windows), cloud sync |
| AI CLIs | Claude Code, Codex, OpenCode |
| Linux desktop | kitty, Nerd Fonts, VS Code, Spotify, Japanese input (Mozc), screen recording; Hyprland extras (hyprbars, hyprfocus, Hyprspace, hyprshell, wayle, kanshi); COSMIC extras (pivot, sysmon, Caffeine, skwd-wall, wl-screenrec) |
| Windows | Windows Terminal, VS Code, YASB, PowerToys, Sysinternals (Microsoft Store), Everything, Wireshark, Nmap, Joplin |
