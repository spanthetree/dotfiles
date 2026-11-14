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
| vim | editor | https://www.vim.org |
| vim-plug | vim plugin manager | https://github.com/junegunn/vim-plug |
| direnv | per-folder environment | https://direnv.net |
| SynthWave '84 | the color theme everything follows | https://github.com/robb0wen/synthwave-vscode |

vim plugins (all on GitHub): [ack.vim](https://github.com/mileszs/ack.vim), [vim-terraform](https://github.com/hashivim/vim-terraform), [vim-ansible-yaml](https://github.com/chase/vim-ansible-yaml), [argtextobj](https://github.com/vim-scripts/argtextobj.vim), [CamelCaseMotion](https://github.com/bkad/CamelCaseMotion), [ctrlp](https://github.com/ctrlpvim/ctrlp.vim), [delimitMate](https://github.com/Raimondi/delimitMate), [editorconfig](https://github.com/editorconfig/editorconfig-vim), [endwise](https://github.com/tpope/vim-endwise), [fugitive](https://github.com/tpope/vim-fugitive), [vim-go](https://github.com/fatih/vim-go), [indent-object](https://github.com/michaeljsmith/vim-indent-object), [vim-javascript](https://github.com/pangloss/vim-javascript), [Jinja2](https://github.com/Glench/Vim-Jinja2-Syntax), [jsonnet](https://github.com/google/vim-jsonnet), [vim-markdown](https://github.com/tpope/vim-markdown), [NERDTree](https://github.com/preservim/nerdtree), [rainbow_parentheses](https://github.com/kien/rainbow_parentheses.vim), [surround](https://github.com/tpope/vim-surround), [TaskList](https://github.com/vim-scripts/TaskList.vim), [tcomment](https://github.com/tomtom/tcomment_vim), [textobj-user](https://github.com/kana/vim-textobj-user), [ALE](https://github.com/dense-analysis/ale), [molokai](https://github.com/tomasr/molokai)

## Modern CLI tools

| Software | Replaces / does | Link |
|---|---|---|
| fzf | fuzzy finder | https://github.com/junegunn/fzf |
| ripgrep (`rg`) | grep | https://github.com/BurntSushi/ripgrep |
| fd | find | https://github.com/sharkdp/fd |
| zoxide (`z`) | cd, by frecency | https://github.com/ajeetdsouza/zoxide |
| eza | ls | https://github.com/eza-community/eza |
| bat | cat, with highlighting | https://github.com/sharkdp/bat |
| btop | top | https://github.com/aristocratos/btop |
| ncdu | du, interactive | https://dev.yorhel.nl/ncdu |
| gdu | ncdu, faster | https://github.com/dundee/gdu |
| dust | du | https://github.com/bootandy/dust |
| duf | df | https://github.com/muesli/duf |
| tealdeer (`tldr`) | short man pages | https://github.com/tealdeer-rs/tealdeer |
| sd | sed find/replace | https://github.com/chmln/sd |
| choose | cut / `awk '{print $2}'` | https://github.com/theryangeary/choose |
| hexyl | hexdump | https://github.com/sharkdp/hexyl |
| hyperfine | time, benchmarking | https://github.com/sharkdp/hyperfine |
| entr | rerun on file change | https://eradman.com/entrproject/ |
| watchexec | rerun on file change | https://github.com/watchexec/watchexec |
| just | make, as a task runner | https://github.com/casey/just |
| procs | ps | https://github.com/dalance/procs |
| viddy | watch, with history | https://github.com/sachaos/viddy |
| yazi | file manager | https://github.com/sxyazi/yazi |
| broot | tree / cd navigator | https://github.com/Canop/broot |
| ouch | tar / zip / unzip | https://github.com/ouch-org/ouch |
| jless | JSON / YAML viewer | https://github.com/PaulJuliusMartinez/jless |
| fx | JSON viewer | https://github.com/antonmedv/fx |
| jq | JSON processor | https://jqlang.org |
| yq | jq for YAML | https://github.com/kislyuk/yq |
| scc, cloc | count lines of code | https://github.com/boyter/scc · https://github.com/AlDanial/cloc |
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
| VS Code | editor | https://code.visualstudio.com |
| Python, pyenv, uv, virtualenvwrapper | Python versions, packages, venvs | https://www.python.org · https://github.com/pyenv/pyenv · https://github.com/astral-sh/uv · https://virtualenvwrapper.readthedocs.io |
| rbenv | Ruby versions | https://github.com/rbenv/rbenv |
| Go, gopls | Go and its language server | https://go.dev · https://pkg.go.dev/golang.org/x/tools/gopls |
| nvm | Node versions | https://github.com/nvm-sh/nvm |
| build-essential and `-dev` libraries | compilers and headers for building Python and Ruby | https://packages.ubuntu.com |

## Kubernetes, cloud, containers

| Software | What | Link |
|---|---|---|
| kubectl | Kubernetes CLI | https://kubernetes.io/docs/reference/kubectl/ |
| kubectx / kubens | switch contexts / namespaces | https://github.com/ahmetb/kubectx |
| k9s | Kubernetes TUI | https://github.com/derailed/k9s |
| stern | multi-pod logs | https://github.com/stern/stern |
| helm | Kubernetes packages | https://helm.sh |
| terraform | infrastructure as code | https://developer.hashicorp.com/terraform |
| ansible | configuration management | https://docs.ansible.com |
| AWS CLI | AWS | https://aws.amazon.com/cli/ |
| Docker, Compose, Buildx | containers | https://docs.docker.com |

## Network

| Software | What | Link |
|---|---|---|
| nmap | port scanner | https://nmap.org |
| tcpdump | packet capture | https://www.tcpdump.org |
| tshark, termshark | Wireshark in the terminal, and its TUI | https://www.wireshark.org · https://termshark.io |
| mtr | traceroute + ping (`mtrr` alias for reports) | https://github.com/traviscross/mtr |
| gping | ping, graphed | https://github.com/orf/gping |
| doggo | dig | https://github.com/mr-karan/doggo |
| dig (bind9-dnsutils) | DNS lookups | https://www.isc.org/bind/ |
| bandwhich | bandwidth per process | https://github.com/imsnif/bandwhich |
| iperf3 | bandwidth test | https://github.com/esnet/iperf |
| tcptraceroute | traceroute over TCP | https://github.com/mct/tcptraceroute |
| whois | domain / IP owner | https://github.com/rfc1036/whois |
| bgpq4 | BGP prefix lists | https://github.com/bgp/bgpq4 |
| ipcalc | subnet calculator | https://jodies.de/ipcalc |
| socat | connect anything to anything | http://www.dest-unreach.org/socat/ |
| httpie, xh (`ht`) | curl for APIs | https://httpie.io · https://github.com/ducaale/xh |
| curl | HTTP | https://curl.se |

## AI

| Software | What | Link |
|---|---|---|
| Claude Code | AI coding CLI | https://github.com/anthropics/claude-code |
| Codex | AI coding CLI | https://github.com/openai/codex |
| OpenCode | AI coding CLI (and desktop app on Windows) | https://opencode.ai |
| Claude Desktop | desktop app (Windows) | https://claude.ai/download |

## Windows

| Software | What | Link |
|---|---|---|
| Windows Terminal | terminal | https://github.com/microsoft/terminal |
| JetBrainsMono Nerd Font | font with icons | https://www.nerdfonts.com |
| YASB | status bar | https://github.com/amnweb/yasb |
| PowerToys | utilities | https://github.com/microsoft/PowerToys |
| Sysinternals Suite | Process Explorer, ZoomIt, Autoruns… | https://learn.microsoft.com/sysinternals/ |
| Everything | instant file search | https://www.voidtools.com |
| Wireshark | packet analyzer | https://www.wireshark.org |
| Nmap (Zenmap) | port scanner | https://nmap.org |
| Git for Windows | git | https://gitforwindows.org |
| WSL | Linux on Windows | https://learn.microsoft.com/windows/wsl/ |
