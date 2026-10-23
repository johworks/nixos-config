# Archer AX1450 root-access experiment

Target: John's Archer AX1450 v1.0 (US), access-point mode, management address
`192.168.10.161`, firmware `1.3.12 Build 20250828 Rel. 26873(5553)`.
The NUC remains the gateway; this desktop uses Ethernet at `192.168.10.122`.

## Initial experiment (2026-10-19)

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

Access was temporary at the end of this initial experiment. The next phase
installed and tested persistence as described below. SSH uses its own
dedicated key, separate from the web admin password.

## Persistent root access (2026-10-19)

Root access now survives reboots. The AP's only writable persistence is its
flash config partitions (squashfs root; `/etc`, `/overlay`, `/tmp` are RAM),
so the injection lives in the settings the firmware already persists:

- `router-config` partition: base64 of the full bootstrap script
  (5KB). This partition has no boot-time consumer; it is only read when the
  web UI downloads a config backup (and overwritten when one is restored).
- `autoreboot` uci config (`user-config` partition): `enable=on`,
  `cycle=week`, `time=03:11`, and a `day` value of
  `* <loader> #`. `S99auto-reboot` regenerates root's crontab from this at
  every boot; the `#` comments out the vendor's reboot command, so the
  entry only runs our loader, daily at 03:11.
- The loader (187 bytes, well under busybox uci's 2047-byte line limit and
  free of `<>&%` for the XML round trip) reads the payload back with
  `nvrammanager -r`, materializes `/etc/ax1450/bootstrap.sh`, and runs it.
- The bootstrap re-adds a `*/30` self-heal crontab line pointing at the
  materialized file, so a dead listener recovers within 30 minutes of
  uptime; a reboot recovers at the next 03:11 (cron-only by design — no web
  admin password is stored anywhere).

The listener pins a dedicated Dropbear RSA host key (embedded in the
payload), so clients keep stable `known_hosts` entries across reboots.
Clients: desktop `ax1450-lab` key and NUC `ax1450-nuc` key; sources
restricted to 192.168.10.122 and 192.168.10.1 on port 2222; password
authentication disabled.

`make-bootstrap.py` regenerates the bootstrap, payload, loader, and pinned
`known_hosts` line from the private key material:

```sh
nix --store daemon shell --no-write-lock-file nixpkgs#python3 --command \
  python3 experiments/ax1450/make-bootstrap.py \
  --host-key .ax1450-private/ax1450_host_key \
  --host-key-pub .ax1450-private/ax1450_host_key.pub \
  --public-key .ax1450-private/id_rsa.pub \
  --public-key .ax1450-private/id_rsa_nuc.pub \
  --ap 192.168.10.161 --port 2222 \
  --allow 192.168.10.122 --allow 192.168.10.1 \
  --output-dir .ax1450-private/persistent
```

Installing a regenerated payload requires (over live root SSH): write
`payload.b64` to the `router-config` partition with `nvrammanager -w`, then
update the `day` value in `/etc/config/autoreboot`, run
`/usr/bin/lua -e 'require("luci.sys.config").saveconfig()'`, and run
`/etc/init.d/auto-reboot start`. Do not use `uci set` for the day option:
TP-Link's uci CLI rejects it, and a failed `uci commit` leaves stale deltas
in `/tmp/.uci/autoreboot` that silently shadow the file (delete that file if
it appears).

Verified by reboot test 2026-10-19: with the schedule temporarily set to a
near-term time, the AP was rebooted; root SSH returned at exactly the
scheduled minute (~8 minutes after the reboot command), key-only, from both
the desktop and the NUC, with AP mode and Wi-Fi intact. The schedule was
then set to its final 03:11 and confirmed in the decrypted `user-config`
partition.

## Nix management and recovery checks

The NUC enables `services.ax1450` from `modules/nixos/ax1450`. Its ten-minute
timer manages the main SSID and PSK on both bands and verifies root-access
persistence. The SSH key and Wi-Fi PSK come from sops. Credentials travel
over SSH stdin, including the router's UCI batch input; they are never put
in the reconcile command's arguments.

Each run decodes the flash bootstrap into a private temporary file and
checks its pinned SHA256 before installing or executing it. The module owns
the AP's single-section `autoreboot` config: enabled, weekly cycle, 03:11,
and the loader day value. It repairs missing, duplicate, or unsafe vendor
cron entries by checking the full expected line. The schedule is on the
AP's clock; SSH can remain unavailable for nearly 24 hours after reboot.

Wi-Fi changes must pass UCI commit, vendor reload, both bands' UCI and
Broadcom runtime SSID/PSK checks, BSS-up checks, and a vendor flash save.
Failures return a nonzero status. Private RAM markers under `/etc/ax1450`
retain pending apply/save work for the next run. A failed flash save retries
without another Wi-Fi reload. A converged run does not reload Wi-Fi or
write flash. These checks verify the vendor's reported state; they do not
replace a client association test with the desired password.

### Declarative Wi-Fi settings

`services.ax1450.wifi.ssid` and the sops secret `ax1450_wifi_psk` continue to
manage the same main network on both bands. Additional options default to
`null`, which leaves the corresponding vendor setting unmanaged. Removing
an option therefore releases ownership; it does not restore a factory value.

| Option under `services.ax1450.wifi` | Values | Vendor setting |
| --- | --- | --- |
| `hidden` | Boolean | Both main BSSes' `hidden` |
| `wps` | Boolean | Both main BSSes' `wps` |
| `smartConnect` | Boolean | `wireless.smart.smart_enable` |
| `radios."2g".enable`, `radios."5g".enable` | Boolean | Inverse of the radio's `disabled_all` |
| `radios.<band>.channel` | `"auto"` or a channel number | Radio `channel` |
| `radios.<band>.channelWidth` | `"auto"`, `"20"`, `"40"`; also `"80"` on 5 GHz | Radio `htmode` |
| `radios.<band>.transmitPower` | `"low"`, `"middle"`, `"high"` | Radio `txpower` |
| `radios.<band>.clientIsolation` | Boolean | Radio `isolate` |

Band names are `"2g"` and `"5g"`. On this device the 2.4 GHz radio is
`wl1` (main section `wl13`, interface `wl1.1`); 5 GHz is `wl0` (`wl03`,
`wl0.1`). The NUC configuration explicitly adopts the settings observed
on the AP: both radios enabled, automatic widths, high transmit power,
2.4 GHz automatic channel, 5 GHz channel 157, visible SSIDs, WPS and Smart
Connect enabled, and client isolation disabled. This preserves existing
behavior rather than choosing new Wi-Fi tuning or security policy.

For example, to select a 20 MHz channel on 2.4 GHz and disable WPS:

```nix
services.ax1450.wifi = {
  ssid = "TP-Link_2724";
  wps = false;
  radios."2g" = {
    channel = 6;
    channelWidth = "20";
  };
};
```

The channel enums match `wl channels` on the owned US AP: 1–11 on 2.4 GHz;
36, 40, 44, 48, 149, 153, 157, 161, 165 on 5 GHz. Channel 165 cannot be
combined with an explicit 40 or 80 MHz width. No country-code changes,
DFS channels or 160 MHz setting are exposed. Widths are maximum capabilities;
coexistence conditions can yield a narrower operating channel. Power presets
use the vendor's 0/12/24 quarter-dB degradation settings, preserving the
existing regulatory limits.

Changes share one UCI commit, one vendor Wi-Fi reload and one flash save.
A reload can briefly disconnect clients on both bands. Subsequent converged
runs do neither. Runtime checks verify BSS up/down state, enabled networks'
SSID/password, fixed primary channels, explicit bandwidth capabilities,
automatic/coexistence NVRAM state, transmit-power degradation, hidden SSID,
client isolation and WPS state. Disabled radios skip checks that require an
active radio, and re-enabling them checks those settings again. The vendor
hardware switch and existing main-BSS enable setting remain authoritative.
The software radio switch affects guest networks too.

Smart Connect is verified in UCI and applied by the vendor reload, which
restarts `nrd`; band-steering behavior has no independent getter in this
module. Disabling Smart Connect still leaves both bands with the same SSID
and password. The firmware disables WPS when an SSID is hidden or its
security mode is incompatible. Client isolation applies within each main
BSS; it does not establish cross-band, VLAN or whole-LAN isolation.

Vendor mappings were inspected in `/lib/wifi/tplink_brcm.sh` and
`/lib/wifi/brcmwifi.sh`; current runtime getters were checked over root SSH.
Regression tests exercise changes, retries, disabled radios and no-op runs
against a mock vendor system. Testing alternate settings on real clients
is separate from checking the current configuration without a reload.
On 2026-10-22, the built wrapper was run twice against the AP after a
read-only desired-state precheck (only local secret paths were redirected).
Both runs reported convergence without reloads, repairs or flash saves.

Offline regression checks run under BusyBox ash with a disposable mock
vendor filesystem, and are included in `nix flake check`:

```sh
nix --store daemon build --no-write-lock-file --no-link \
  .#checks.x86_64-linux.ax1450-reconcile
nix --store daemon flake check --no-write-lock-file
nix --store daemon build --no-write-lock-file --no-link \
  .#nixosConfigurations.nuc.config.system.build.toplevel
```

After switching the NUC configuration, inspect convergence with
`systemctl status ax1450-reconcile.timer` and
`journalctl -u ax1450-reconcile.service -n 30`. An immediate run is
`sudo systemctl start ax1450-reconcile.service`.

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
replacement web interface, or remove telemetry services. The persistence
uses only the vendor's own config storage. Restoring any older config
backup through the web UI overwrites both config partitions and removes the
persistence; a firmware upgrade or factory reset does the same. Root access
does not add missing drivers, additional flash storage, or a supported
upstream OpenWrt upgrade path. Further customization should account for
the stock kernel and proprietary Wi-Fi stack.
