# Desktop security upgrade, October 2026

Tracks `nixos-uez`, following the [audit](security-audit-2026-10-22.md).
The desktop was activated and reboot-verified on 23 October 2026.

## Prepared changes

The workstation input now uses the 20 October NixOS unstable snapshot rather
than the May snapshot. Home Manager, Firefox add-ons and independent application
inputs were refreshed alongside it. The candidate includes Firefox 158.0,
Node.js 24.21.0, OpenSSL 3.5.9 and kernel 6.18.57.

The new NixOS CA module blocks the affected roots. The shared
`modules/nixos/common/security.nix` also patches standalone cacert, certifi,
pip's vendored bundle and Python's ensurepip wheel. These are targeted runtime
dependency replacements, preserving package names and Python ABI. This avoids
rebuilding every compiler and desktop dependency for a certificate-data change.
The package version strings for backported bundle fixes remain unchanged.
Remove these temporary backports once the locked packages contain equivalent
fixes; the bootstrap patch does not downgrade newer bundled pip wheels.

Electron 42 is replaced with the official 42.11.16 Linux binary, which includes
upstream's compromised-intermediate mitigation. OpenCode's embedded Bun is
wrapped to select the filtered system CA store instead of its bundled roots.
The Electron replacement preserves its existing ABI and executable layout.
See the [Electron release notes](https://releases.electronjs.org/release/v42.11.16).

The Realtek r8125 driver needs a deterministic module certificate with the new
kernel tooling. Its desktop package generates that certificate after fixup,
preserving the driver and r8169 blacklist needed by this NIC. This upgrade
selects classic D-Bus, while the previous desktop generation used dbus-broker.
Activation required staging for boot and rebooting because the switch inhibitor
refuses changing the running system bus implementation. Secure Boot signing
uses the existing local Lanzaboote keys.

## Verification

The complete desktop candidate was built without switching. Candidate Python
certifi and pip-vendored bundles rejected the compromised emSign chain and
accepted `https://example.com/`. A fresh virtual environment bootstrapped pip
26.2.2 and its bundle rejected the compromised chain. These tests used no
credentials or TLS-verification bypasses. Node's HTTPS client was also checked
against the candidate OS CA store; rejection includes OpenSSL's `INVALID_PURPOSE`
error for explicitly distrusted roots.

Electron's HTTPS client rejected all four compromised chains in Node mode and
rejected the no-CT chain in normal headless application mode, with a successful
ordinary HTTPS control. OpenCode's embedded Bun rejected all four chains and
accepted the control through its installed wrapper.

Existing virtual environments keep their own packages. The accessible home
scan during the audit found none, but independently managed environments or
applications outside this configuration require their own updates. Restart
applications after activation so running processes use the new libraries and
trust stores. The previous generation remains available for rollback.

## Stage and reboot

Upgrade the NUC first to checkpoint and migrate the shared Beads database
before the desktop starts using its new Beads client. From the reviewed
checkout, without updating the lock again:

```sh
cd ~/nixos-config
nix --store daemon flake check --no-write-lock-file
nix --store daemon build --no-write-lock-file \
  .#nixosConfigurations.desktop.config.system.build.toplevel -o result-desktop-security
sudo nixos-rebuild boot --no-write-lock-file --flake .#desktop
```

After the boot command succeeds, save your work and reboot with `sudo reboot`.
If an earlier `switch` attempt failed its D-Bus inhibitor, the running system
remains on the old generation even though the system profile may point at the
candidate. The boot command installs the candidate for the next startup.

After logging in, check normal browsing and Ethernet, then run the
[credential-free certificate checks](security-audit-2026-10-22.md#remediation-and-verification-sequence).
All compromised-chain URLs must fail certificate verification while ordinary
HTTPS succeeds. A timeout is inconclusive. Check `uname -r`, Ethernet, Secure
Boot and `systemctl --failed`; the prepared kernel is 6.18.57.

The [NUC upgrade](security-upgrade-nuc-2026-10.md) has separate database backups,
container changes and router verification steps.

## Post-reboot verification, 23 October

The active system is `zbw2cc9ycj2hjhbix4ncad2a7vki9znw`, running kernel
6.18.57. Secure Boot is enabled, Ethernet uses r8125 9.016.01-NAPI, D-Bus and
Home Manager are healthy, and there are no failed system units. John confirmed
normal browsing. The installed Beads 1.3.1 client reads the migrated shared
database, and the user tunnel is active.

All 35 targeted TLS checks passed: curl, Node 24.21.0, Electron 42.11.16 in
Node mode, OpenCode's embedded Bun 1.4.2 through its installed wrapper, and
native Python 3.14.8 with default SSL, deployed certifi, and a fresh venv's
pip 26.2.2 bundle. Each rejected all four compromised chains with certificate
errors while `https://example.com/` returned 200.

This does not certify every dependency copy. Older ensurepip bundles remain
in Steam's 32-bit Python library dependency and a GStreamer documentation tool;
follow-up `nixos-nzf` records their scope and the direct-interpreter test.
Steam's normal Python executable selects the patched native interpreter.
The NUC kernel reboot is also verified; its remaining application and WAN
checks are listed in the [NUC upgrade](security-upgrade-nuc-2026-10.md).
