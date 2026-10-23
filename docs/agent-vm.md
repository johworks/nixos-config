# Disposable NixOS VMs for local agents

Investigation: 2026-10-23. Beads: `nixos-vyh`. Baseline: `bbad9f8`;
Nixpkgs: `02c087f3fe673c9e317f206a627cb6b910336dbe`.

Use a QEMU/KVM NixOS guest with its own disk and bootloader. Keep the agent
on the desktop, give it SSH access and passwordless sudo **inside the guest**,
and run the laptop's Hyprland session as an ordinary guest user. Start each
experiment with a fresh writable overlay over a reproducible base image.
This is a recommendation with successful Nix evaluation, not a running VM.

## What is already available

- `flake.nix` exports `nixosConfigurations.vm`.
- `hosts/vm/home.nix` imports `hosts/laptop/home.nix`, including the shared
  Hyprland, Waybar and theme modules. Desktop appearance changes already have
  a route to both laptop and guest.
- The VM system configuration is separate from the laptop system configuration.
  Testing it does not establish that laptop-only system settings work.
- `scripts/install-vm.sh` is an installer that partitions a target disk. It is
  not needed for a generated QEMU VM; do not use it on the desktop for this lab.
- The desktop has about 30 GiB RAM and 623 GiB disk free. Outside the agent
  sandbox, `/dev/kvm` is readable/writable and two GPU render nodes exist.
  The sandbox hides both KVM and DRM devices. KVM AMD modules are loaded.
  No host rebuild was performed or established as necessary.

The current VM variant evaluates with SSH disabled, wheel sudo requiring a
password, 1 GiB RAM, unrestricted user networking, and no explicit accelerated
GPU. Its host store share is read-only; guest store writes use a tmpfs overlay.
It also gets the Nixpkgs default exchange-directory shares.

## Which VM approach fits

| Approach | Fit for this use |
| --- | --- |
| NixOS `system.build.vm` / `build-vm` | Fast disposable configuration preview. Shares the host store by default and directly boots the generated kernel. |
| NixOS `system.build.vmWithBootLoader` | Recommended lab base. Includes a bootable disk with the guest closure, supports persistent guest rebuilds/reboots, and generates a launcher with a writable disk overlay. |
| QEMU under libvirt / virt-manager | Useful later for a managed VM inventory and console UI; adds a management service and policy decisions. Session and system instances have different privilege models. |
| microvm.nix | Worth revisiting for many headless service experiments. Adds a flake input and hypervisor choices; no need to introduce it for the first graphical lab. |
| Containers or nested Hyprland on the desktop | Do not provide the separate guest kernel and system environment required for these root experiments. |

[Nix's VM tutorial](https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html)
describes generated QEMU guests. The exact defaults and boot behavior above
were checked against the
[locked QEMU module](https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/virtualisation/qemu-vm.nix)
and [VM variant module](https://github.com/NixOS/nixpkgs/blob/02c087f3fe673c9e317f206a627cb6b910336dbe/nixos/modules/virtualisation/build-vm.nix).
The direct-boot option explicitly documents that it will not correctly reboot
into a different configuration switched on disk. That makes the bootloader
variant preferable for agents doing `nixos-rebuild switch` and reboot tests.
See also [libvirt's driver architecture](https://libvirt.org/drvqemu.html)
and [microvm.nix's introduction](https://microvm-nix.github.io/microvm.nix/).

## Proposed guest boundary

1. Launch QEMU as an unprivileged host process. Require KVM with
   `virtualisation.qemu.forceAccel = true`. Access to a guest's root account
   does not require host root. Initially the launcher needs execution outside
   this session's device-hiding sandbox; a later narrowly scoped launcher can
   provide the same route without granting arbitrary host sudo.
2. Give the guest its own complete Nix store and disk. Force
   `virtualisation.sharedDirectories = lib.mkForce { };` to remove even the
   built-in exchange shares. Set `mountHostNixStore = false` and
   `useHostCerts = false`. Do not attach physical disks or host service sockets.
   A read-only host store prevents writes but exposes other store contents;
   a closure copied into the disk avoids that extra exposure.
3. Use a separate lab SSH key. Keep its private half on the desktop and install
   only its public half in the guest. Forward `127.0.0.1:2222` to guest port 22;
   disable SSH passwords and direct root login. Guest `john` gets passwordless
   wheel sudo, while Hyprland runs as `john`. Pin the guest host key in a
   lab-specific known-hosts file, including reset/first-boot handling.
4. Start with `restrictNetwork = true`. The explicit incoming SSH forwarding
   remains available, but guest-initiated host/Internet traffic is blocked.
   Host-side builds can send closures with `nix copy` over SSH, and source
   snapshots can be copied with SCP. Ordinary NAT does **not** isolate the guest
   from host services or the LAN. If guest-side downloads become necessary,
   add host-enforced egress rules or a limited proxy; a guest firewall is
   editable by guest root.
5. Copy a source snapshot into the guest rather than sharing the live working
   tree. Keep agent credentials, SSH agents, SOPS keys and personal home files
   on the desktop. Keep Beads tracking on the desktop too; the imported profile
   includes a Beads tunnel but it should not receive the NUC private key.
6. Keep each experiment's disk overlay, EFI variables, SSH identity state,
   control socket, serial log and output artifacts in one run directory.
   Shut down before discarding disk state; export useful patches and evidence
   first. Pin the base image with a GC root while overlays depend on it.

These controls constrain accidental guest damage and access. They are not a
claim that a VM eliminates hypervisor vulnerabilities. QEMU's
[security model](https://www.qemu.org/docs/master/system/security.html) supports
KVM virtualization on the relevant machine types; its TCG emulation has a
different security policy. The
[network option documentation](https://www.qemu.org/docs/master/system/invocation.html)
defines `restrict=on` and its forwarding exception. The
[image documentation](https://www.qemu.org/docs/master/tools/qemu-img.html)
describes backing images and warns against modifying an image while in use.

## Hyprland preview and agent inspection

Use VirtIO GPU with VirGL and a local OpenGL display, initially a QEMU GTK
window: `-vga none -device virtio-vga-gl -display gtk,gl=on`.
The [Hyprland tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/#vm)
requires VM 3D acceleration and says to run Hyprland without root. QEMU's
[VirtIO GPU documentation](https://www.qemu.org/docs/master/system/devices/virtio/virtio-gpu.html)
explains its accelerated backends and host GPU requirements. The locked QEMU
package enables GTK and VirGL on this Linux configuration.

Disable automatic SPICE clipboard integration for the initial lab. Set up a
guest-only graphical login or disposable local password; the current account
has no lab login provisioned. Then inspect the guest session through SSH using
`hyprctl`, user-service logs, and screenshots captured inside the guest.
Guest root can execute session commands as `john` with the correct runtime
directory and Hyprland instance. Desktop keyboard shortcuts can intercept guest
bindings, so input capture also needs a manual check.

VirGL introduces host graphics code into the boundary. A stricter headless
service lab can omit graphics; the Hyprland lab needs this explicit tradeoff.
Actual accelerated rendering on the desktop's GPU/driver combination remains
unverified. A VM can validate themes, windows, bindings, portals and startup
services; physical touchpad behavior, backlight, battery, suspend, dock outputs
and the laptop GPU still need checks on the laptop.

## Evaluated configuration sketch

This module was applied to `nixosConfigurations.vm` with `extendModules` in a
scratch expression. It evaluated the resulting `system.build.vmWithBootLoader`
derivation successfully. It is not installed or wired into the flake.
Lab public-key provisioning and graphical login still need implementation.

```nix
{ lib, ... }:
{
  virtualisation.vmVariantWithBootLoader = {
    networking.hostName = lib.mkForce "agent-vm";
    virtualisation = {
      cores = 4;
      memorySize = 8192;
      diskSize = 65536;
      mountHostNixStore = false;
      useHostCerts = false;
      sharedDirectories = lib.mkForce { };
      restrictNetwork = true;
      forwardPorts = [
        {
          from = "host";
          host.address = "127.0.0.1";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      qemu.forceAccel = true;
      qemu.options = [
        "-vga none"
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    security.sudo.wheelNeedsPassword = false;
    services.spice-vdagentd.enable = lib.mkForce false;
  };
}
```

Evaluation confirmed `useBootLoader = true`, `useEFIBoot = true`, no host store
mount or shared directories, the loopback SSH forward, restricted networking,
and Hyprland enabled. `writableStore = false` here means no overlay over a
shared store; the full guest disk still holds a normal writable store.
Existing Home Manager deprecation warnings were reported. Evaluation also
realized intermediate derivations through the repo's dependency replacement
mechanism. The VM disk and launcher were not fully built, and no guest boot,
SSH connection, screenshot or isolation test was performed.

## Small implementation and verification plan

Keep VM-specific settings in one local module under `hosts/vm`, applied only
to the lab variant. Add a small launcher for start, SSH, stop and reset,
using one overlay and loopback port per run. Provision the public key and guest
graphical login, and ensure rebuilds target the bootable lab configuration
rather than silently reverting to the unmodified `vm` host.

The intended loop is: desktop worktree -> build/copy guest configuration ->
guest activation as root -> inspect Hyprland as `john` -> collect patch, logs
and screenshot -> reset. Offline `nix copy` needs a complete closure and
dependency set; prove that transfer before relying on guest-side rebuilds.

Before calling the lab usable, verify:

- The base disk builds and boots under KVM; SSH `sudo -n id -u` returns `0`.
- Hyprland starts as `john`, reports a working renderer and no config errors;
  Waybar, a terminal and portals function, with a screenshot as evidence.
- A source/config change reaches the guest, activates successfully and remains
  selected after reboot. Use the bootable lab configuration for that rebuild.
- No host directories or credentials appear in the guest; host file hashes
  remain unchanged after a deliberate guest write experiment.
- Guest connections to a temporary host test listener, a LAN test endpoint and
  the Internet fail in restricted mode, while host-to-guest SSH works.
- A fresh run loses a guest-created marker and returns to the base generation;
  repeated runs have distinct state and evidence directories.
- `nix --store daemon flake check --no-write-lock-file` passes before any
  eventual host switch. No host switch is part of this investigation.

Later, [NixOS VM integration tests](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)
can automate reproducible boot and service checks with guest superuser access.
Use those once the manual graphical loop works.
