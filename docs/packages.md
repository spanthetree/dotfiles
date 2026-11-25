# Packages

[`packages.yaml`](../packages.yaml) is the one list for both systems: `linux:` (apt, apt repos, GitHub releases, install scripts) and `windows:` (winget ids). Its keys are documented at the top of the file.

- **Add:** add a line, re-run `install.cmd`.
- **Remove:** delete its line and re-run. The installer asks, then uninstalls it, but only if it installed it on that machine (recorded in `~/.local/state/dotfiles/linux.json` and `%LOCALAPPDATA%\dotfiles\windows.installed`).
- **Existing machine:** run `install.cmd --adopt` once, so what's already installed counts as managed.
- **Language tools:** list them under their language's entry as `tools:` (go: `go install`, uv: `uv tool install`, ruby: `gem install` into mise's global Ruby, krew: `kubectl krew install`). They install after the language and leave with it.
- **Opt-in desktops:** entries with `when: hyprland` or `when: cosmic` install only on machines run with `--hyprland` / `--cosmic` (remembered per machine). `--no-hyprland` / `--no-cosmic` uninstalls them as if their lines were deleted. `when: in-hyprland` (the Hyprland layer) runs only from inside Hyprland or where `--hyprland` was chosen; elsewhere it's skipped, not removed.
- **Private apps:** an entry with `private:` (Beeper) holds private data. Before installing it, `linux/monitoring-check` (Windows: `windows/monitoring-check.ps1`) looks for software that can read the machine's files or record its screen: endpoint security, DLP, file-query agents, screen monitoring. If it finds none, the app installs as usual. If it finds some, it lists them and asks (default no; `--yes` and a run with no terminal also mean no). The answer is kept until the findings change, in `~/.local/state/dotfiles/private.json` (Windows: `%LOCALAPPDATA%\dotfiles\private.json`); delete it to be asked again. Finding nothing isn't proof that a machine is private.
- **Updates:** each run upgrades apt packages (`settings.upgrade`) and re-downloads GitHub binaries in `~/.local/bin` when a newer release is out.

Core packages (git, curl, zsh, python3...) are never removed. An apt package counts as installed by this repo only if apt has it as installed by hand, so a library already there as another package's dependency is never claimed. One that other installed packages still need is never removed: it stays as an ordinary dependency. Every apt removal is simulated first and refused if apt would take anything more, or anything essential or part of the desktop. `settings.autoremove` also clears the dependencies those removals left unneeded, nothing else.

## Highlights

The same groups as `packages.yaml`, where every entry has a comment saying what it's for.

| Group | Tools |
|---|---|
| Shell and terminal | zsh, byobu (tmux), vim, Starship, fzf, carapace, navi, zoxide, direnv, tldr, tmux-fingers |
| Files, search and system | ripgrep, fd, eza, bat, duf, gdu, dust, procs, btop, viddy, yazi, broot, ouch, sd, choose, hexyl |
| Data and logs | jq, yq, jaq, fx, gron, jc, lnav, VisiData, rare |
| Languages and runtimes | mise with Python 3.11/3.12 (global)/3.14, Ruby 3.2/3.4 (global)/4.0 (prebuilt) and Go (latest, plus gopls); uv; rustup (stable Rust); nvm |
| Dev tools | gh, delta, lazygit, difftastic, gitleaks, shellcheck, just, watchexec, hyperfine, scc, d2, grpcurl, websocat, usql, kcat, sops + age, step |
| Containers and Kubernetes | Docker, kubectl + krew plugins, kubectx, k9s, stern, kubeshark, helm + helm-diff, helmfile, kind, containerlab |
| Cloud and IaC | AWS CLI, granted, tenv (terraform/tofu/terragrunt), tflint, terraform-docs, infracost, steampipe, ansible |
| Network | mtr (`mtrr` report alias), trippy (`trip`), gping, fping, hping3, scamper, iperf3; dig, doggo, whois, ipcalc, grepcidr, mapcidr, asn, bgpq4, monocle, globalping; nmap, RustScan, arp-scan, lldpd; tcpdump, tshark, termshark, ngrep, tcpflow, rustnet, eBPF (pwru, bpftrace, BCC); xh, oha; gnmic, SuzieQ, TTP + ntc-templates; autossh (`tun`), sshs, termscp |
| Notes and AI | Joplin (terminal app; desktop app on Linux desktops and Windows), Claude Code, Codex, OpenCode |
| Linux desktop | Nerd Fonts, kitty, VS Code, Spotify, Joplin, Beeper (after checking the machine for software that could read your chats), Japanese input (Mozc), screen recording |
| Hyprland (opt-in) | the Hyprland desktop setup, hyprbars, hyprfocus, Hyprspace, wayle, hyprshell, kanshi |
| COSMIC (opt-in) | COSMIC, pivot, sysmon, Caffeine, the EN/あ input applet, skwd-wall, wl-screenrec |
| Windows | Windows Terminal, YASB, VS Code, PowerToys, Sysinternals (Microsoft Store), Everything, Wireshark, Nmap, Joplin, Beeper, Claude, OpenCode |
