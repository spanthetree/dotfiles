<p align="center">
  <img src="docs/logo-v2.svg" alt="dotfiles: SynthWave '84 terminal setup for WSL, Linux and Windows. zsh, byobu, starship, vim, Windows Terminal, YASB, modern CLI tools" width="780">
</p>

```sh
gh repo clone spanthetree/dotfiles ~/dotfiles
~/dotfiles/install.cmd --packages     # Linux or WSL; on Windows: install.cmd
```

New machine, options, and how to uninstall: see [install](docs/install.md).

## Tour

<p align="center">
  <img src="docs/media/byobu.gif" alt="byobu with tabs for btop, lazygit, yazi and vim, then the Alt-D popup searching every tab's text and jumping to a match" width="100%">
</p>

| | |
|:-:|:-:|
| ![zsh with the Starship prompt and the byobu status bar](docs/media/terminal.png) | ![several byobu tabs, btop in front](docs/media/tabs.png) |
| zsh, Starship and the 4-row byobu status bar | tabs, with the current one highlighted |
| ![Alt-D popup listing every tab with a preview](docs/media/search-tabs.png) | ![Alt-D popup searching the text of every tab](docs/media/search-text.png) |
| `Alt-D`: every tab in every session, with a preview | typing searches the text in every tab too |

<details>
<summary>The installer</summary>
<p align="center"><img src="docs/media/installer.gif" alt="install.cmd --packages: themed sections, spinners with elapsed time, a check mark per step" width="100%"></p>
</details>

## Docs

| Doc | Covers |
|---|---|
| [Install](docs/install.md) | Linux/WSL and new-Windows-machine installs, options, uninstall, per-machine files, VS Code |
| [Hotkeys](docs/hotkeys.md) | keys this repo adds, then each app's defaults (byobu, zsh, fzf, vim, Windows Terminal, TUI tools, AI CLIs, Windows apps) |
| [Software](docs/software.md) | everything installed, with links |
| [Packages](docs/packages.md) | `packages.yaml`: adding, removing, updating, what's included |
| [Layout](docs/layout.md) | what each file in the repo is and where it is linked |
| [FAQ](docs/faq.md) | common questions: undo, native Linux, WSL vs Windows, keys, fonts |
| [Development](docs/development.md) | versioning and checks |
| [Changelog](CHANGELOG.md) | every release |

## Contributing

Pull requests are accepted only for verified bug fixes and interface improvements. For anything else (packages, themes, keys, tools), fork it and maintain your own copy however you like.

## License

[MIT](LICENSE)
