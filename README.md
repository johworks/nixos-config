# NixOS Config

## Overview
- Flake-based NixOS + Home Manager (as a NixOS module).
- Hosts target a laptop, a NUC server, and a VM for desktop testing.
- Secrets managed with sops-nix (NUC only today).

## Hosts
- `laptop`: Hyprland desktop + SDDM (Wayland), personal workstation.
- `nuc`: XFCE + LightDM, server-focused services and modules.
- `vm`: Hyprland desktop + SDDM, mirrors the laptop Home Manager profile for testing.
- `default`: legacy/placeholder config (KDE Plasma 6), not used in flake outputs.

## Shared Config
- `modules/nixos/`: reusable NixOS modules (services, apps, infra).
- `modules/home/`: Home Manager modules and profiles.
- `hosts/<name>/`: host-specific `configuration.nix`, `hardware-configuration.nix`, `home.nix`.
- `wallpapers/`: shared assets used by desktop profiles.

## VM Install
- Boot the NixOS installer and connect to Wi-Fi.
- Clone this repo.
- Run `sudo ./scripts/install-vm.sh --disk /dev/vda` and let it reboot.
