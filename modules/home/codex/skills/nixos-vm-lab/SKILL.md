---
name: nixos-vm-lab
description: Develop and validate NixOS flake changes in the selectable, isolated NixOS VM lab. Use when an agent needs to boot, activate, inspect, or visually test a candidate configuration in a guest.
---

# NixOS VM lab

Use the `nixos-lab` launcher from John's NixOS configuration repository to test
a selected flake's `nixosConfigurations` output in a separate QEMU guest. The
target flake need not be the repository supplying the launcher. Read that
repository's `docs/nixos-lab.md` for current commands, guest overrides and
limitations; use a checkout that contains `packages.x86_64-linux.nixos-lab`.

## Development loop

1. Select the requested flake, configuration and existing guest user. Identify
   its physical hardware module, if any, and pass its path relative to the
   flake root with `--hardware`. Add a small `--compat` module only for
   host-specific settings incompatible with the guest. The desktop's existing
   compatibility module disables its physical Secure Boot and Windows entry.
2. Give each experiment its own private `--state` directory and SSH port. State
   is bound to the selection and persists across restarts. Build the launcher
   from the lab repository, then use `start` with the selected flake; add
   `--window` if a visible QEMU window is useful. The lab needs host KVM and a
   render node; if the agent sandbox hides them, use the normal permission
   mechanism to launch outside it as the ordinary host user.
3. Make candidate changes in the chosen worktree. Use `deploy` with the same
   selection arguments to build, copy and activate the guest configuration;
   use `exec --root -- ...` for guest administration and `reboot` for
   startup-dependent changes. `build` updates the base, while `reset` stops the
   current run and starts fresh on the next `start`, retaining old artifacts.
   Do not assume SSH readiness means the graphical session is ready.
4. Verify the behavior affected by the change. For visual work, exercise the
   relevant UI, capture screenshots with `shot`, and actually inspect them;
   retain useful evidence and report observed failures. Screenshots currently
   support Hyprland and Plasma; for Hyprland-specific input and smoke tests,
   see `docs/hyprland-lab.md`. Stop the guest when no longer needed unless the
   user wants it left running.

Guest root is isolated from the physical host, but the selected flake is
evaluated on the host. Use trusted flakes, avoid copying real credentials into
the guest, and do not expose host filesystems or sockets without explicit need.
Hardware and service assumptions may need guest overrides; report what the VM
does and does not validate. Do not switch the physical desktop: provide the user
with the verified change and let them perform the live switch.
