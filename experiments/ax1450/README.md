# Archer AX1450 root-access experiment

Target: John's Archer AX1450 v1.0 (US), access-point mode, management address
`192.168.10.161`, firmware `1.3.12 Build 20250828 Rel. 26873(5553)`.
The NUC remains the gateway; this desktop uses Ethernet at `192.168.10.122`.

## Verified result (2026-10-19)

The owned AP returned `uid=0(root) gid=0(root) groups=0(root)` over SSH.
Its kernel reports `Linux Archer_AX10 4.1.52 ... armv7l`.

From this checkout, connect with:

```sh
experiments/ax1450/ssh
experiments/ax1450/ssh id
```

The wrapper uses the local private key and recorded host key, and scopes the
older server's RSA compatibility options to this connection. The listener is
`192.168.10.161:2222`, accepts keys only, disables forwarding, and permits only
source `192.168.10.122`. Verified root command execution and rejection of
password login; a connection from the NUC timed out as expected. The extra
test listener on 2223 was stopped and confirmed closed.

The original disabled scheduler (`03:00`, weekly, Monday) and original NTP
peers were restored through the vendor API. No injected cron entries remain;
the AP still reports access-point mode. The original backup and a fresh
post-cleanup backup are retained privately.

**Access is temporary until the AP reboots.** Persistent access has not been
installed or tested. The existing web admin password is still the temporary
password John set during reset; SSH uses its own dedicated key.

## Evidence and approach

The [official V1.6 download](https://www.tp-link.com/us/support/download/archer-ax1450/v1.60/)
contains the matching build. The firmware BIN has SHA256
`e3c78e25a23d661219b1934d3b94ba7d0844cd357fede8a830b90e60fd0a910c`.
Its SquashFS starts at offset `90798`. The extracted
`/etc/init.d/auto-reboot` places the configured day directly into a root
crontab entry, matching the
[community finding](https://github.com/maxilosgr/archer-ax10-root-exploit/tree/4189c8b21d21419844ea6edeb77e12b75d10802e).

`prepare-backup.py` adapts that configuration-backup method. It changes only
the scheduler and NTP blocks of the user and router configuration members,
preserves archive metadata and unrelated members, and verifies encryption
round trips. TP-Link's configuration format is not valid XML: it includes
numeric element names. The helper therefore replaces narrowly matched blocks
without reserializing the other settings.

The temporary bootstrap uses the stock Dropbear binary on TCP 2222:

- Dedicated RSA key; password login and SSH forwarding disabled.
- Listener bound to the AP's IPv4 management address.
- INPUT rules permit this desktop and drop other sources on that port.
- No unauthenticated telnet listener or third-party binary downloads.

TP-Link's Dropbear additionally needs `-L` ("Enable SSH session login").
Without it, public-key authentication succeeds but shell, PTY and exec
requests fail. The option was confirmed in the shipped binary's usage text.

The community method relies on the boot clock starting at midnight and
temporarily replaces NTP peers with `192.0.2.1` to trigger at 00:03. On this
device that did not keep the clock at midnight. Setting the time manually
through the UI also disables the scheduler. The authenticated scheduler API
`/admin/reboot?form=set` accepts a time relative to the router's current clock
while keeping its time mode `auto`; this avoids another restore/reboot.
Original scheduler and NTP settings must be restored after the experiment.

The tested request path is the stock UI's authenticated, encrypted AJAX
service, `$.su.moduleManager.query("reboot").services.ajax.request(...)`.
Read `/admin/time?form=settings` to obtain the device's current time, then
write `/admin/reboot?form=set` with `enable=on`, `cycle=week`, a time two
minutes ahead, and the intended command in `day`. The vendor API accepts
that field without validating it. Keep a recovery backup and restore all
scheduler fields afterward. The live successful attempt used this path to
enable the stock server's session flag; no unauthenticated telnet was used.

## Local private files

`.ax1450-private/` at the repository root is mode 700 and excluded via
`.git/info/exclude`. It contains the original configuration backup, the
dedicated SSH key, the modified backup, and its decoded bootstrap script.
Backup files and keys must never be staged or committed. Browser artifacts
are separately excluded through the same local Git exclusion file.

From the repository root, prepare a new output file with Python and OpenSSL:

```sh
nix --store daemon shell --no-write-lock-file nixpkgs#python3 nixpkgs#openssl --command \
  python3 experiments/ax1450/prepare-backup.py \
  .ax1450-private/original-after-reset.bin \
  .ax1450-private/id_rsa.pub \
  .ax1450-private/root-access.bin
```

The helper prepares a file only. Restoring it through System → Backup &
Restore reboots the AP and interrupts Wi-Fi. The original backup is the
recovery file. A factory reset is the fallback if management becomes
unavailable; it also erases the Wi-Fi and AP settings.

## Boundaries

This experiment does not flash firmware, modify the bootloader, install a
replacement web interface, or remove telemetry services. The SSH files and
process are temporary until persistence is separately implemented and tested.
The configuration injection itself is persistent until removed; do not leave
the altered scheduler or NTP settings behind after testing.

Root access does not add missing drivers, additional flash storage, or a
supported upstream OpenWrt upgrade path. Further customization should account
for the stock kernel and proprietary Wi-Fi stack.
