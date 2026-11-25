# Software

Everything this repo installs or configures, with links. The list itself is [`packages.yaml`](../packages.yaml).

## Shell and terminal

| Software | What | Link |
|---|---|---|
| zsh | shell | https://www.zsh.org |
| antidote | zsh plugin manager | https://github.com/mattmc3/antidote |
| zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search | zsh plugins | https://github.com/zsh-users |
| Starship | prompt and byobu status row | https://starship.rs |
| byobu | tmux with a status bar and F-keys | https://www.byobu.org |
| tmux | terminal multiplexer under byobu | https://github.com/tmux/tmux |
| tmux-resurrect, tmux-continuum | save and restore tabs | https://github.com/tmux-plugins/tmux-resurrect · https://github.com/tmux-plugins/tmux-continuum |
| tmux-fingers | `F12 F`: label URLs, paths, IPs, hashes on screen and copy one | https://github.com/Morantron/tmux-fingers |
| carapace | completions for commands zsh has none for | https://github.com/carapace-sh/carapace-bin |
| navi | cheatsheet picker (`Ctrl-G`), with denisidoro/cheats | https://github.com/denisidoro/navi |
| kitten (`icat`) | kitty's helper: images in the terminal | https://sw.kovidgoyal.net/kitty/kittens/icat/ |
| vim | editor | https://www.vim.org |
| vim-plug | vim plugin manager | https://github.com/junegunn/vim-plug |
| direnv | per-folder environment | https://direnv.net |
| SynthWave '84 | the color theme everything follows | https://github.com/robb0wen/synthwave-vscode |

vim plugins (all on GitHub): [ack.vim](https://github.com/mileszs/ack.vim), [vim-terraform](https://github.com/hashivim/vim-terraform), [vim-ansible-yaml](https://github.com/chase/vim-ansible-yaml), [argtextobj](https://github.com/vim-scripts/argtextobj.vim), [CamelCaseMotion](https://github.com/bkad/CamelCaseMotion), [ctrlp](https://github.com/ctrlpvim/ctrlp.vim), [delimitMate](https://github.com/Raimondi/delimitMate), [editorconfig](https://github.com/editorconfig/editorconfig-vim), [endwise](https://github.com/tpope/vim-endwise), [fugitive](https://github.com/tpope/vim-fugitive), [vim-go](https://github.com/fatih/vim-go), [indent-object](https://github.com/michaeljsmith/vim-indent-object), [vim-javascript](https://github.com/pangloss/vim-javascript), [Jinja2](https://github.com/Glench/Vim-Jinja2-Syntax), [jsonnet](https://github.com/google/vim-jsonnet), [vim-markdown](https://github.com/tpope/vim-markdown), [NERDTree](https://github.com/preservim/nerdtree), [rainbow_parentheses](https://github.com/kien/rainbow_parentheses.vim), [surround](https://github.com/tpope/vim-surround), [TaskList](https://github.com/vim-scripts/TaskList.vim), [tcomment](https://github.com/tomtom/tcomment_vim), [textobj-user](https://github.com/kana/vim-textobj-user), [ALE](https://github.com/dense-analysis/ale), [molokai](https://github.com/tomasr/molokai)

## Modern CLI tools

| Software | Replaces / does | Link |
|---|---|---|
| fzf | fuzzy finder (its release, not apt) | https://github.com/junegunn/fzf |
| ripgrep (`rg`) | grep | https://github.com/BurntSushi/ripgrep |
| fd | find | https://github.com/sharkdp/fd |
| zoxide (`z`) | cd, by frecency | https://github.com/ajeetdsouza/zoxide |
| eza | ls | https://github.com/eza-community/eza |
| bat | cat, with highlighting | https://github.com/sharkdp/bat |
| btop | top, htop (`top`, `htop` aliases) | https://github.com/aristocratos/btop |
| gdu | ncdu, faster (`ncdu` alias) | https://github.com/dundee/gdu |
| dust | du | https://github.com/bootandy/dust |
| duf | df | https://github.com/muesli/duf |
| tealdeer (`tldr`) | short man pages (its release: Ubuntu 24.04's can't download pages) | https://github.com/tealdeer-rs/tealdeer |
| sd | sed find/replace | https://github.com/chmln/sd |
| choose | cut / `awk '{print $2}'` | https://github.com/theryangeary/choose |
| hexyl | hexdump | https://github.com/sharkdp/hexyl |
| hyperfine | time, benchmarking | https://github.com/sharkdp/hyperfine |
| watchexec | rerun on file change | https://github.com/watchexec/watchexec |
| just | make, as a task runner | https://github.com/casey/just |
| procs | ps | https://github.com/dalance/procs |
| viddy | watch, with history (`watch` alias) | https://github.com/sachaos/viddy |
| yazi | file manager | https://github.com/sxyazi/yazi |
| broot | tree / cd navigator | https://github.com/Canop/broot |
| ouch | tar / zip / unzip | https://github.com/ouch-org/ouch |
| fx | JSON viewer | https://github.com/antonmedv/fx |
| jq | JSON processor | https://jqlang.org |
| jaq | jq, faster | https://github.com/01mf02/jaq |
| gron | JSON to greppable lines | https://github.com/tomnomnom/gron |
| jc | command output to JSON | https://github.com/kellyjonbrazil/jc |
| lnav | log viewer: merge, filter, SQL | https://lnav.org |
| rare | histograms and tables from log lines | https://github.com/zix99/rare |
| VisiData (`vd`) | spreadsheet TUI for CSV, JSON, SQLite... | https://www.visidata.org |
| yq | jq for YAML | https://github.com/kislyuk/yq |
| scc | count lines of code (`cloc` alias) | https://github.com/boyter/scc |
| xclip | clipboard from the shell | https://github.com/astrand/xclip |

## Git and development

| Software | What | Link |
|---|---|---|
| git | version control | https://git-scm.com |
| gh | GitHub CLI | https://cli.github.com |
| delta | git pager with highlighting | https://github.com/dandavison/delta |
| difftastic (`difft`) | structural diff | https://github.com/Wilfred/difftastic |
| lazygit | git TUI | https://github.com/jesseduffield/lazygit |
| shellcheck | shell script linter | https://www.shellcheck.net |
| d2 | diagrams from text | https://d2lang.com |
| sops, age | encrypted secrets in files, and its keys | https://github.com/getsops/sops · https://github.com/FiloSottile/age |
| step | certificates, TLS inspection, JWTs | https://github.com/smallstep/cli |
| grpcurl | curl for gRPC | https://github.com/fullstorydev/grpcurl |
| websocat | netcat for WebSockets | https://github.com/vi/websocat |
| usql | one SQL CLI for many databases | https://github.com/xo/usql |
| kcat | Kafka CLI | https://github.com/edenhill/kcat |
| mise | Python, Ruby and Go versions, global and per project | https://mise.jdx.dev |
| VS Code | editor | https://code.visualstudio.com |
| httpstat | curl with a timing breakdown | https://github.com/reorx/httpstat |
| Python, uv, virtualenvwrapper | packages, tools, venvs | https://www.python.org · https://github.com/astral-sh/uv · https://virtualenvwrapper.readthedocs.io |
| Ruby | language (versions from mise) | https://www.ruby-lang.org |
| Go, gopls | Go (versions from mise) and its language server | https://go.dev · https://pkg.go.dev/golang.org/x/tools/gopls |
| rustup | Rust toolchains (rustc, cargo, clippy, rustfmt, rust-analyzer) | https://rustup.rs |
| nvm | Node versions | https://github.com/nvm-sh/nvm |
| build-essential and `-dev` libraries | compilers and headers for native extensions, and Python or Ruby versions with no prebuilt build | https://packages.ubuntu.com |

## Kubernetes, cloud, containers

| Software | What | Link |
|---|---|---|
| kubectl | Kubernetes CLI | https://kubernetes.io/docs/reference/kubectl/ |
| kubectx / kubens | switch contexts / namespaces | https://github.com/ahmetb/kubectx |
| k9s | Kubernetes TUI | https://github.com/derailed/k9s |
| stern | multi-pod logs | https://github.com/stern/stern |
| kind | throwaway local Kubernetes clusters in Docker (upstream Kubernetes; also a containerlab node kind) | https://kind.sigs.k8s.io |
| krew + neat, tree, view-secret, node-shell, df-pv, who-can | kubectl plugins | https://krew.sigs.k8s.io |
| kubeshark | cluster API traffic viewer | https://github.com/kubeshark/kubeshark |
| helm, helm-diff, helmfile | Kubernetes packages, upgrade diffs, declared releases | https://helm.sh · https://github.com/databus23/helm-diff · https://github.com/helmfile/helmfile |
| tenv (`terraform`, `tofu`, `terragrunt`) | Terraform/OpenTofu/Terragrunt versions per project | https://github.com/tofuutils/tenv |
| tflint, terraform-docs, infracost | Terraform lint, module docs, cost estimates | https://github.com/terraform-linters/tflint · https://terraform-docs.io · https://www.infracost.io |
| steampipe | SQL over cloud APIs | https://steampipe.io |
| granted (`assume`) | AWS profile switching | https://github.com/common-fate/granted |
| ansible | configuration management | https://docs.ansible.com |
| AWS CLI | AWS | https://aws.amazon.com/cli/ |
| Docker, Compose, Buildx | containers | https://docs.docker.com |
| containerlab | network labs as containers, from a topology file | https://containerlab.dev |
| netshoot (`netshoot`, `knetshoot` functions) | network tools inside a container's or pod's namespace (image, pulled on first use) | https://github.com/nicolaka/netshoot |

## Network

| Software | What | Link |
|---|---|---|
| nmap | port scanner | https://nmap.org |
| tcpdump | packet capture | https://www.tcpdump.org |
| tshark, termshark | Wireshark in the terminal, and its TUI | https://www.wireshark.org · https://termshark.io |
| mtr | traceroute + ping (`mtrr` alias for reports) | https://github.com/traviscross/mtr |
| trippy (`trip`) | traceroute + ping TUI with AS names, charts and a world map (GeoIP from MaxMind GeoLite2) | https://github.com/fujiapple852/trippy |
| geoipupdate | keeps MaxMind's GeoLite2 database current (for trippy's map) | https://github.com/maxmind/geoipupdate |
| SuzieQ (`suzieq-cli`, `suzieq-gui`, `sq-poller`) | polls routers, switches and Linux hosts over SSH; query interfaces, routes, ARP, MACs and paths across them | https://github.com/netenglabs/suzieq |
| rustnet | network monitor TUI: connections per process (PPA domcyrus/rustnet) | https://github.com/domcyrus/rustnet |
| autossh | ssh that reconnects by itself, for tunnels and port forwards (`-L`, `-R`, `-D`) | https://www.harding.motd.ca/autossh/ |
| gitleaks | finds secrets in git changes (this repo's pre-commit hook) | https://github.com/gitleaks/gitleaks |
| sshs | pick a host from `~/.ssh/config` and connect (`sshs` alias adds SynthWave colours) | https://github.com/quantumsheep/sshs |
| termscp | TUI file transfer and explorer: SFTP, SCP, FTP, S3, SMB, WebDAV | https://github.com/veeso/termscp |
| gping | ping, graphed | https://github.com/orf/gping |
| doggo | dig | https://github.com/mr-karan/doggo |
| dig (bind9-dnsutils) | DNS lookups | https://www.isc.org/bind/ |
| iperf3 | bandwidth test | https://github.com/esnet/iperf |
| whois | domain / IP owner | https://github.com/rfc1036/whois |
| bgpq4 | BGP prefix lists | https://github.com/bgp/bgpq4 |
| ipcalc | subnet calculator | https://jodies.de/ipcalc |
| socat | connect anything to anything | http://www.dest-unreach.org/socat/ |
| xh (`ht`, `http`, `https`) | curl for APIs, httpie's syntax | https://github.com/ducaale/xh |
| oha | HTTP load test | https://github.com/hatoo/oha |
| asn | AS, prefixes, peers, reputation for an IP/ASN/domain | https://github.com/nitefood/asn |
| globalping | ping/traceroute/dig/http from probes worldwide | https://github.com/jsdelivr/globalping-cli |
| monocle | BGP data: MRT, RPKI, AS names | https://github.com/bgpkit/monocle |
| gnmic | gNMI client | https://gnmic.openconfig.net |
| TTP, ntc-templates (`ntc`) | parse CLI output | https://github.com/dmulyalin/ttp · https://github.com/networktocode/ntc-templates |
| lldpd | LLDP/CDP neighbours | https://lldpd.github.io |
| RustScan, nmap-formatter | fast port discovery; nmap XML to HTML/CSV/MD/D2 | https://github.com/bee-san/RustScan · https://github.com/vdjagilev/nmap-formatter |
| arp-scan, fping, hping3, scamper | LAN discovery, ping sweeps, crafted probes, bulk measurement | https://github.com/royhills/arp-scan · https://fping.org · https://github.com/antirez/hping · https://www.caida.org/catalog/software/scamper/ |
| grepcidr, mapcidr | grep by CIDR; CIDR maths | https://www.pc-tools.net/unix/grepcidr/ · https://github.com/projectdiscovery/mapcidr |
| ngrep, tcpflow, conntrack, ethtool | grep packets, TCP streams to files, netfilter connections, NIC settings | https://github.com/jpr5/ngrep · https://github.com/simsong/tcpflow · https://conntrack-tools.netfilter.org · https://www.kernel.org/pub/software/network/ethtool/ |
| pwru, bpftrace, BCC tools | eBPF: packet drops, one-liners, `*-bpfcc` tools | https://github.com/cilium/pwru · https://bpftrace.org · https://github.com/iovisor/bcc |
| curl | HTTP | https://curl.se |

## Notes

| Software | What | Link |
|---|---|---|
| Joplin (`joplin`, desktop app on Linux and Windows) | Markdown notes and to-dos, synced through Joplin Cloud, OneDrive, Dropbox, Nextcloud/WebDAV or S3 | https://joplinapp.org |
| Beeper (Linux desktop and Windows) | one app for WhatsApp, Signal, Telegram, Matrix and more | https://www.beeper.com |

## AI

| Software | What | Link |
|---|---|---|
| Claude Code | AI coding CLI | https://github.com/anthropics/claude-code |
| Codex | AI coding CLI | https://github.com/openai/codex |
| OpenCode | AI coding CLI (and desktop app on Windows) | https://opencode.ai |
| Claude Desktop | desktop app (Windows) | https://claude.ai/download |

## Linux desktop

Only on a Linux desktop (not WSL). Hyprland and COSMIC only with `install.cmd --hyprland` / `--cosmic`; the Hyprland extras go on any installed Hyprland.

| Software | What | Link |
|---|---|---|
| kitty | terminal | https://sw.kovidgoyal.net/kitty/ |
| JetBrainsMono, FantasqueSansM, DepartureMono, Terminess Nerd Fonts | fonts with icons: kitty uses Departure Mono (retro-futuristic pixel); Terminess (Terminus) to switch to | https://www.nerdfonts.com |
| fcitx5 + Mozc, ibus + Mozc | Japanese input: Hyprland and COSMIC, GNOME | https://fcitx-im.org · https://github.com/google/mozc |
| slurp, wf-recorder | screen recording: area picker, recorder (Hyprland) | https://github.com/emersion/slurp · https://github.com/ammen99/wf-recorder |
| Spotify | music | https://www.spotify.com/download/linux/ |
| Ubuntu-Hyprland, Hyprland-Dots | the Hyprland desktop setup (waybar, rofi, swaync, hyprlock, wallust...) | https://github.com/LinuxBeginnings/Ubuntu-Hyprland · https://github.com/LinuxBeginnings/Hyprland-Dots |
| hyprbars, hyprfocus | Hyprland plugins: title bars, focus flash | https://github.com/hyprwm/hyprland-plugins |
| Hyprspace | Hyprland workspace overview | https://github.com/KZDKM/Hyprspace |
| hyprshell | Hyprland `Alt-Tab` and launcher | https://github.com/H3rmt/hyprshell |
| wayle | Hyprland panel, to try in place of waybar | https://github.com/wayle-rs/wayle |
| kanshi | monitor layouts on plug / unplug | https://gitlab.freedesktop.org/emersion/kanshi |
| COSMIC | System76's desktop, from the hepp3n/cosmic-epoch PPA | https://system76.com/cosmic · https://launchpad.net/~hepp3n/+archive/ubuntu/cosmic-epoch |
| pivot | COSMIC `Alt-Tab` with live previews | https://github.com/Sigma-studios/pivot |
| sysmon, Caffeine | COSMIC panel applets: system monitor, keep awake | https://github.com/leonardo-panseri/cosmic-ext-applet-sysmon · https://github.com/Oussamaberchi/caffeine-cosmic |
| input applet (this repo) | COSMIC panel: fcitx5's input method as EN / あ | `linux/cosmic/input-applet` |
| skwd-wall | COSMIC wallpaper picker with Wallhaven search | https://github.com/liixini/skwd-wall |
| wl-screenrec | screen recording (COSMIC) | https://github.com/russelltg/wl-screenrec |

## Windows

| Software | What | Link |
|---|---|---|
| Windows Terminal | terminal | https://github.com/microsoft/terminal |
| Wallpapers (this repo) | Wallhaven wallpaper picker, `Ctrl-Alt-W` | `windows/wallpapers.ps1` |
| JetBrainsMono Nerd Font | font with icons | https://www.nerdfonts.com |
| YASB | status bar | https://github.com/amnweb/yasb |
| PowerToys | utilities | https://github.com/microsoft/PowerToys |
| Sysinternals Suite | Process Explorer, ZoomIt, Autoruns… | https://learn.microsoft.com/sysinternals/ |
| Everything | instant file search | https://www.voidtools.com |
| Wireshark | packet analyzer | https://www.wireshark.org |
| Nmap (Zenmap) | port scanner | https://nmap.org |
| Git for Windows | git | https://gitforwindows.org |
| WSL | Linux on Windows | https://learn.microsoft.com/windows/wsl/ |
