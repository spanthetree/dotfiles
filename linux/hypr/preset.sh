# shellcheck shell=bash disable=SC2034
# Answers for the Hyprland desktop setup's installer (LinuxBeginnings/Ubuntu-Hyprland, `install.sh --preset`), run by
# the hyprland-desktop entry in packages.yaml (install.cmd --hyprland). Its options checklist opens with these ticked.
# Sourced by that installer (bash); Y/N or ON/OFF.

gtk_themes=Y    # its dark/light switch needs them
bluetooth=Y
thunar=Y        # its file manager (Super-E)
input_group=Y   # waybar's keyboard-state module reads input devices
dots=Y          # its Hyprland config (Hyprland-Dots), which linux/hypr/dotfiles.lua sits on top of
ags=N           # its desktop overview: Hyprspace (packages.yaml) is the overview here
sddm=N          # keep the login screen Ubuntu has (GDM): Hyprland, GNOME and COSMIC are picked there
sddm_theme=N
zsh=N           # this repo sets up zsh (linux/zsh)
pokemon=N
rog=N
# NVIDIA's driver setup only where there is an NVIDIA GPU (PCI vendor 0x10de)
nvidia=N
grep -qx 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null && nvidia=Y
