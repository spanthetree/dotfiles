:; exec bash "$(dirname "$0")/linux/install.sh" "$@"  # Linux/WSL: sh reads only this line
@echo off
rem dotfiles installer for both systems. Linux/WSL: ./install.cmd (or sh install.cmd) runs linux/install.sh.
rem Windows: install.cmd runs windows\install.ps1. Options: ./install.cmd --help on Linux.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\install.ps1" %*
