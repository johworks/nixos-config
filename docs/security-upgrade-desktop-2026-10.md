# Desktop security upgrade, October 2026

Tracks `nixos-uez`, following the [audit](security-audit-2026-10-22.md).
The running desktop is unchanged until activation.

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
preserving the driver and r8169 blacklist needed by this NIC. The desktop also
keeps classic D-Bus during the upgrade so switching does not replace the running
session bus. Secure Boot signing still uses the existing local Lanzaboote keys.

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

## Activate

Upgrade the NUC first to checkpoint and migrate the shared Beads database
before the desktop starts using its new Beads client. From the reviewed
checkout, without updating the lock again:

```sh
cd ~/nixos-config
nix --store daemon flake check --no-write-lock-file
nix --store daemon build --no-write-lock-file \
  .#nixosConfigurations.desktop.config.system.build.toplevel -o result-desktop-security
sudo nixos-rebuild switch --no-write-lock-file --flake .#desktop
```

Check normal browsing and Ethernet, then run the
[credential-free certificate checks](security-audit-2026-10-22.md#remediation-and-verification-sequence).
All compromised-chain URLs must fail certificate verification while ordinary
HTTPS succeeds. A timeout is inconclusive. Reboot to activate the new kernel,
then check `uname -r`, Ethernet, Secure Boot and `systemctl --failed`.

The [NUC upgrade](security-upgrade-nuc-2026-10.md) has separate database backups,
container changes and router verification steps.
