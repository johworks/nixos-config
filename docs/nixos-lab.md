# NixOS experiment lab

`nixos-lab` boots a selected NixOS flake configuration in a disposable QEMU
guest. The selected flake supplies the system and Home Manager configuration;
the lab adds virtual hardware, guest SSH and passwordless guest sudo. Agents
build and activate changes in the guest; the user switches the physical host.

Build the launcher from this repository, then select any compatible flake and
NixOS configuration. `--hardware` names the physical hardware module relative
to the selected flake root. A configuration can require an additional guest
compatibility module for assumptions outside that hardware file.

```sh
nix --store daemon build --no-write-lock-file .#nixos-lab --out-link /tmp/nixos-lab-cli

/tmp/nixos-lab-cli/bin/nixos-lab --state /tmp/laptop-lab \
  --flake .#laptop --hardware hosts/laptop/hardware-configuration.nix \
  start --port 2223

/tmp/nixos-lab-cli/bin/nixos-lab --state /tmp/desktop-lab \
  --flake .#desktop --hardware hosts/desktop/hardware-configuration.nix \
  --compat scripts/nixos-lab/desktop-compat.nix start --port 2224
```

The desktop override disables its physical Secure Boot setup and Windows boot
entry. Use a different state directory and SSH port for every concurrent
experiment. A state directory is bound to its flake selection, hardware module,
compatibility module and guest user; it cannot be reused for another selection.
The default guest user is `john`; pass `--user` for an existing user in another
flake. The guest autologs in as that user. Configurations that do not provide a
graphical session can still be accessed through SSH.

The lab backports QEMU's EGL cleanup fix for version 11.1.2 to prevent a host
QEMU crash when accelerated guests exit. Existing runs retain their original
QEMU launcher: run `build` followed by `reset` with the same selection to use
the fixed launcher in a fresh run. `reset` retains the previous disk and
artifacts; the new run starts with a fresh disk.

Repeat the same selection arguments with `exec --root -- id`, `deploy`, `reboot`,
`shot /tmp/desktop.png`, `status`, `stop`, or `reset`. `deploy` builds from the
selected flake, copies its closure into the guest and activates it there. `build`
updates the base image for the next fresh run; `reset` stops the guest and
retains its previous disk and artifacts. `start --window` opens a QEMU window;
the default is a headless accelerated display. Screenshots currently support
Hyprland through grim and Plasma through Spectacle; other desktops may need a
different capture method. SSH readiness does not imply that the graphical
session has finished starting.

Guests have separate writable disks and EFI state, no host filesystem shares,
restricted guest-initiated networking, and per-run pinned SSH keys. Root inside
the guest does not require host sudo. Launching QEMU needs access to `/dev/kvm`
and a GPU render node, which may require running outside an agent sandbox. Do
not copy personal credentials into guests. Guest isolation does not guarantee
protection from hypervisor or graphics driver flaws. The host evaluates the
selected flake, so only use flakes you trust.

Hardware, secrets, services and desktop assumptions vary between flakes. A VM
does not validate physical GPU, monitors, bootloader, suspend, or peripherals.
The original [Hyprland lab](hyprland-lab.md) retains its compositor-specific
input and verification tools.
