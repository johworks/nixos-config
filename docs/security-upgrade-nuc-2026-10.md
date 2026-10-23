# NUC security upgrade, October 2026

Tracks `nixos-3ec` and `nixos-7s8`; the baseline and certificate work is
`nixos-uez`. The freshly rebuilt NUC still runs NixOS 25.11 from May, Synapse
1.152.0 and Vaultwarden 1.37.3. Rebuilding an unchanged lock file does not fetch
security updates. On October 22 it had no failed units, monitoring was active,
and its curl still accepted the compromised emSign chain.

## Prepared configuration

- Move the stable system and Home Manager inputs to 26.05. Keep
  `system.stateVersion = "25.05"`.
- Preserve PostgreSQL major 16 and `/var/lib/postgresql/16`; update its patch
  release. Add a daily Synapse SQL dump at 01:15 in `/var/backup/postgresql`.
  These local dumps retain the current and previous backup, not off-host recovery.
- Update Synapse to 1.163.0, Vaultwarden to 1.37.4, and nginx to 1.30.6 through
  the refreshed inputs. Vaultwarden uses the `X-Real-IP` header overwritten by
  its direct local nginx proxy.
- Keep classic D-Bus during this router migration to avoid changing the running
  system bus implementation during an ordinary switch. The kernel and initrd
  update still require a later reboot.
- Generate a persistent private Grafana encryption key at startup; 26.05 no
  longer supplies the historical public default. This dashboard's only live
  data source is the provisioned, unauthenticated local Prometheus instance.
  It has no declared credentials to re-encrypt. Back up Grafana's database
  before activation if any manually added credentials must be preserved; its
  root-only historical records were not inspected.
- Preserve Stubby's exact running strict DNS-over-TLS policy explicitly;
  importing the package's example required a build during evaluation.
- Use the stable channel's default Python for DDNS; the old Python 3.11 pin
  could not evaluate the current Cloudflare dependency toolchain.
- Allow DNS, DHCP, mDNS, Home Assistant, ESPHome, and the analysis dashboard
  only through LAN `vlan20`. Grafana remains LAN-only. The analysis dashboard
  additionally binds `192.168.10.1`.
- Pin Home Assistant 2026.10.2 and ESPHome 2026.10.0 by registry digest. Mount
  the filtered NixOS CA store into each image and select it for OpenSSL,
  Requests, and pip. Home Assistant's explicit certifi and vendored pip bundles
  are also replaced with this read-only file. Keep the certificate directory
  filtered too, so OpenSSL cannot fall back to old hashed roots inside an image.

Stremio moves from its unmaintained Node 14 container to a native systemd
service using pinned server 4.22.4, Node.js 22.23.4 and FFmpeg 8.1.2. nginx
continues to proxy port 11470, now bound to loopback. `/var/lib/stremio` remains
the application state directory; systemd assigns it to the new service user.
The FFmpeg package enables certificate and hostname verification by default
and selects the filtered CA bundle, covering redirects and nested HLS resources.
The unmodified FFmpeg package disables verification by default.
Internal HTTPS and casting remain disabled; public HTTPS terminates at nginx.
A conditional startup migration changes the old container cache path
`/root/.stremio-server` to `/var/lib/stremio`, preserving other settings.

Beads clients update from 1.0.3 to 1.3.1 alongside Dolt 1.86.6. Back up the
shared database before the first new client connects, and upgrade the NUC
before the desktop client. Do not run a candidate Beads client against the
live database during build verification. Schema changes can require restoring
that backup when rolling back; a NixOS generation rollback alone is insufficient.

## Container verification

Candidate images were pulled into isolated rootless Podman storage on the
desktop; the running NUC containers were not accessed or restarted. The
recorded digests identify the multi-platform image manifest, with the local
tests selecting Linux amd64.

| Image | Manifest digest | Packages inspected |
| --- | --- | --- |
| Home Assistant 2026.10.2 | `sha256:33afb0659d786213264c2211f8d91c5fe87461c56eba6a3a546eb05fc71e89f4` | Python 3.14.6, certifi 2026.7.22, pip 26.0.1 |
| ESPHome 2026.10.0 | `sha256:1dff19a59070cdb523b76576cdc74d200f862d43c1407809088855920cf57145` | Python 3.14.6, certifi 2026.10.19, pip 26.2.2 |

Unmodified Home Assistant accepted the bad emSign chains in both urllib and
Requests. Unmodified ESPHome's new certifi rejected all four test chains in
Requests, but urllib accepted all four via its OS store. With the declared
mounts and environment settings, urllib and Requests in both images rejected
all four compromised chains with certificate-verification errors, while
`https://example.com/` succeeded. No credentials or exploit payloads were used.
This verifies TLS trust behavior, not every integration or device workflow.

## Before activation, on the NUC

Build/check as John first. Do not update the lock file again between verifying
the build and activating it.

```sh
cd ~/nixos-config
nix --store daemon flake check --no-write-lock-file
nix --store daemon build --no-write-lock-file \
  .#nixosConfigurations.nuc.config.system.build.toplevel -o result-nuc-security
```

The existing Vaultwarden local backup succeeded at 21:40 on October 22; the
encrypted S3 job succeeded at 00:19. Refresh it immediately before upgrading.
Make a new PostgreSQL dump with the running server's tools before Synapse can
apply migrations. The new SQL backup timer is not available before activation.
The following paths deliberately keep the dump private to postgres:

```sh
sudo systemctl start vw-backup-to-s3.service beads-dolt-backup.service
sudo install -d -m 0700 -o postgres -g postgres /var/backup/security-upgrade-2026-10
sudo -u postgres /run/current-system/sw/bin/pg_dump \
  --format=custom --file=/var/backup/security-upgrade-2026-10/matrix-synapse.dump \
  matrix-synapse
sudo -u postgres /run/current-system/sw/bin/pg_restore \
  --list /var/backup/security-upgrade-2026-10/matrix-synapse.dump >/dev/null
```

Stop the old Stremio container before archiving its state and switching:

```sh
sudo systemctl stop podman-stremio.service
sudo tar -C /var/lib -czf /var/backup/security-upgrade-2026-10/stremio.tar.gz stremio
```

Create and download a Home Assistant backup from its Settings > System > Backups
page before changing the image. Preserve `/var/lib/esphome` and
`/var/lib/stremio`; archive them while their containers are stopped if a
consistent application snapshot is needed. Database dumps and archives on the
same disk are useful for upgrade rollback; copy them off the NUC for disk recovery.

## Activate and verify

Keep a local console or a second SSH session available on this router. Once
backups and the build are verified:

```sh
sudo nixos-rebuild switch --no-write-lock-file --flake .#nuc
sudo systemctl restart podman-home-assistant.service podman-esphome.service stremio.service
systemctl --failed
systemctl is-active beads-dolt stremio
bd ready --json
curl --fail http://127.0.0.1:8008/_synapse/admin/v1/server_version
curl --fail https://vault.goobhub.org/alive
curl --fail http://192.168.10.1:8123/ >/dev/null
curl --fail http://192.168.10.1:6052/ >/dev/null
curl --fail http://192.168.10.1:8091/ >/dev/null
curl --fail http://127.0.0.1:11470/settings >/dev/null
curl --fail https://stream.goobhub.org/settings >/dev/null
dig @192.168.10.1 example.com
sudo systemctl start postgresqlBackup-matrix-synapse.service
systemctl status postgresqlBackup-matrix-synapse.service --no-pager
sudo podman ps --format '{{.Names}} {{.Image}} {{.Status}}'
```

Use the [audit's compromised-chain checks](security-audit-2026-10-22.md#remediation-and-verification-sequence)
with each actual runtime. All four compromised test URLs must fail certificate
verification; `https://example.com/` must succeed. A timeout or unrelated network
failure is inconclusive. Check Matrix messaging/calling, Vaultwarden login/sync,
Home Assistant integrations, ESPHome device discovery, and Stremio playback
(including a transcoded stream) from a LAN client.

From a separate client on WAN `vlan10`, verify TCP 53, 3000, 6052, 8091 and
8123 cannot connect and DNS UDP 53 does not answer. A test on the NUC itself
does not exercise inbound firewall interface rules. Keep public HTTPS and
Matrix media connectivity working. After upgrading the desktop, verify
`systemctl --user is-active beads-tunnel` and `bd ready --json` there too.
Reboot in a planned router outage, then
check `uname -r`, DNS/DHCP/NAT, and `systemctl --failed` again.

Synapse's upstream [upgrade notes](https://element-hq.github.io/synapse/latest/upgrade.html)
were reviewed for 1.152.0 through 1.163.0. The removed MSC3861/MAS mode and
the new profile-request assertion are not enabled here. Existing legacy
MatrixRTC configuration remains supported. Retain the database dump before
trying a rollback; a NixOS generation rollback alone does not undo database
migrations. Vaultwarden's [1.37.4 upgrade notes](https://github.com/dani-garcia/vaultwarden/releases/tag/1.37.4)
also describe obsolete clients and organization API-key rotation if untrusted
organization administrators had access.
