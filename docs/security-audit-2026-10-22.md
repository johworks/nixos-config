# Security audit — 22 October 2026

Audit task: `nixos-6bn`. Repository baseline:
`5002a5f29d4c20f64076223118bb62d2cc7e56d5`.
Times are America/New_York; the audit ran after midnight UTC on 23 October.

Concurrent commit `e94b53c` added NUC network monitoring during the audit.
Its source was also reviewed: Grafana binds `192.168.10.1:3000`, its firewall
allowance is LAN-only, and Prometheus/exporters bind loopback. These services
were absent from the inspected running-service/listener inventory. Their full
dependency advisories were not separately enumerated; include them in the NUC
baseline refresh before deployment.

## Result and scope

Patching is needed. Both the desktop and NUC accepted a certificate chained
through a compromised eMudhra intermediate during credential-free HTTPS checks.
The NUC also runs an affected Synapse release and predates additional
Vaultwarden, nginx and OpenSSL security releases. No configured PHP web service
was found.

This audit evaluated all four host configurations and inspected the running
desktop and NUC. Laptop and VM deployment state was not inspected. It is a
targeted advisory and configuration review, not an exhaustive vulnerability
scan of every transitive dependency or an investigation for prior compromise.
No package pins, services, certificates, firewall rules or containers were changed.

## Prioritized work

| Priority | Finding | Action | Beads task |
| --- | --- | --- | --- |
| P1 | Compromised CA chains accepted by desktop and NUC clients | Update OS and application trust stores; verify rejection in each relevant runtime | `nixos-uez` |
| P1 | NUC uses unsupported NixOS 25.11; both primary package snapshots date from May | Move NUC and its Home Manager to supported stable; refresh workstation inputs and independent application pins | `nixos-uez` |
| P1 | Synapse 1.152.0 is below a published denial-of-service fix | Upgrade Synapse to a current release, at least 1.157.2 for the cited issue | `nixos-3ec` |
| P1 | Vaultwarden 1.37.3 predates the 1.37.4 security release | Update its independent input and matching web vault | `nixos-3ec` |
| P1 | nginx 1.28.3 and OpenSSL 3.6.1/3.6.2/3.6.4 predate later security fixes | Update packages and inspect configuration-specific applicability | `nixos-3ec`, `nixos-uez` |
| P1 | Three running OCI images have unverified internal packages and trust stores | Inventory rootful images, refresh tested images, recreate and verify | `nixos-7s8` |
| P1 | Management-service firewall allowances include the WAN interface | Restrict intended LAN services to LAN and verify from both sides | `nixos-7s8` |

Priorities reflect this deployment, not CVSS scores. Some fixes overlap: a
baseline refresh can update several packages together, but containers and
independent inputs need explicit attention.

## Package and deployment evidence

`flake.lock` pins the main unstable input to `549bd84d6279` (5 May 2026)
and stable to `b77b3de87756` (22 May 2026). The independent Vaultwarden
input dates from September; the OpenCode input dates from October. Updating
one independent input does not update the system baseline.

| Component | Desktop | NUC | Evidence |
| --- | --- | --- | --- |
| System | 26.05.20260505.549bd84 | 25.11.20260522.b77b3de | `/run/current-system` |
| Running kernel | 6.18.26 | 6.12.90 | `uname -r` |
| OS CA package | nss-cacert 3.121 | nss-cacert 3.123, also 3.121 in closure | Evaluation and deployed closure |
| Python | 3.13.12 | 3.13.12, with additional Python dependencies | Evaluation and closure |
| Python certifi | 2026.01.04 | 2025.07.14 and 2026.01.04 | Deployed closure |
| Node.js | 24.14.1 | 22.22.2 | Deployed closure |
| Firefox | 150.0.1 | Not assessed as a deployed browser | Desktop closure |
| Electron | 41.3.0 | Not assessed | Desktop closure |
| nginx | No enabled service found | 1.28.3 | Running service command on NUC |
| Synapse | No enabled service found | 1.152.0 | Running service command on NUC |
| Vaultwarden | No enabled service found | 1.37.3 | Running service command on NUC |
| LiveKit | No enabled service found | 1.11.0 | Evaluated service package and closure |
| OpenSSL | 3.6.1 | 3.6.2; 3.6.1 and 3.6.4 also in closure | Deployed closure |

Available packages are not necessarily installed. In particular, the evaluated
package sets offer pip 25.3 / 25.0.1, uv 0.11.8 / 0.9.30 and PHP 8.4.20 /
8.4.21 for unstable / stable respectively. No standalone pip or uv installation
was established by the runtime inventory. `system.autoUpgrade.enable` evaluates
to false on all hosts; no NUC container-refresh timer appeared in the timer list.

## eMudhra/emSign certificate incident: confirmed exposure

The number **4** was an elliptic-curve private-key value, not the contents of
an entire certificate. Compromised intermediate keys allow impersonation of TLS
services. Browser revocation feeds and non-browser trust stores have different
update paths, and cross-signed chains also require attention.
See the [original disclosure and checker](https://emudhra.we-have-a-problem.com/).

The following checks used normal TLS verification, no credentials and no
`--insecure` option:

| Client | emSign chain | AAA cross-signed chain | emSign chain without CT | AAA chain without CT |
| --- | --- | --- | --- | --- |
| Desktop curl | HTTP 200: accepted | TLS verification failure, exit 60 | Not separately tested | Not separately tested |
| NUC curl | HTTP 200: accepted | TLS verification failure, exit 60 | HTTP 200: accepted | TLS verification failure, exit 60 |
| Desktop Node.js 24.14.1 | Not separately tested | Not separately tested | HTTP 200: accepted | Not separately tested |
| Desktop Python 3.13.12, default SSL context | Not separately tested | Not separately tested | HTTP 200: accepted | Not separately tested |

NUC curl and desktop Python GET responses from the no-CT test explicitly
reported a successful connection.
A desktop curl request to `https://example.com/` returned HTTP 200 as a normal
HTTPS control. Accepting even one compromised path establishes exposure;
rejecting the AAA path does not make the client safe. These tests establish
trust behavior at audit time, not whether anyone previously intercepted traffic.

The desktop Python default SSL context still lists `emSign ECC Root CA - G3`
and `AAA Certificate Services`. NUC certificate-subject inspection also found
these roots. Python, Node, Electron and applications with bundled Go/Rust trust
data must be considered separately from the OS bundle. Browser revocation-feed
state was not inspected, so Firefox's version alone does not prove whether it
accepted these particular intermediates.

The [Python security announcement](https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576)
recommends certifi 2026.10.19, pip 26.2.2 and uv 0.13.4 or newer. Upstream pip
includes its own certifi trust, so updating only the host CA bundle is insufficient
for an unmodified old pip. Existing virtual environments need separate checks.

Nix packaging matters: the locked unstable certifi derivation replaces its
bundle with a reference to that snapshot's `cacert`, and supports
`NIX_SSL_CERT_FILE`. This is an immutable store reference; it does not mean
every old Python closure will automatically use a newly activated OS bundle.
The old pip derivation retains upstream vendoring. Verify the actual installed
bundle and patches instead of judging a Nix package solely by upstream version.

Upstream already has a NixOS-specific mitigation in the current
[unstable CA module](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-unstable/nixos/modules/security/ca.nix)
and [26.05 CA module](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/nixos/modules/security/ca.nix):
both explicitly exclude affected roots from the system bundle. Their standalone
`cacert` package still reports 3.126. This makes updating the NixOS module
important, and reinforces the need to test application bundles that reference
`pkgs.cacert` directly. A package version below a generic upstream target is not
enough to determine whether this distribution mitigation is present.

No `pyvenv.cfg` was found in the accessible home-tree scan; one backup staging
directory was permission denied. Containers and other accounts were not covered.

## PHP2Shell: no declared PHP web deployment found

All four evaluated hosts have no PHP-FPM pools and have Apache disabled.
Neither inspected system closure contains a PHP runtime. The active NUC
services are nginx proxies, Rust/Go/Python services and the three OCI containers;
no declared WordPress, Nextcloud or other PHP application was found. Unimported
modules, such as the old Pi-hole configuration, were not counted as running.

The package sets do contain old PHP versions, but availability in Nixpkgs is
not exposure. The [PHP advisory](https://www.php.net/archive/2026.php#2026-10-21-5)
identifies CVE-2026-109618 and CVE-2026-109619 and fixes in 8.2.35, 8.3.36,
8.4.27 and 8.5.12. If PHP is found inside a container, separate installation or
network appliance, check for those fixes or a documented vendor backport.
Container interiors and AP firmware were not cleared by this audit.

## Other service patch requirements

**Synapse:** the NUC runs 1.152.0 behind nginx at `matrix.goobhub.org`.
[GHSA-6wjm-9p2x-gvpm / CVE-2026-102592](https://github.com/element-hq/synapse/security/advisories/GHSA-6wjm-9p2x-gvpm)
affects versions before 1.157.2 and permits memory exhaustion via crafted
multipart requests. The configured 100 MB upload/request limits may reduce
impact but do not establish safety. Federation is disabled by policy, but this
does not remove the client HTTP surface. Upgrade to a current release and review
the other intervening advisories. No exploit request was sent.

**Vaultwarden:** the actual service uses the independent package at 1.37.3,
not the base package set's 1.36.0. The
[1.37.4 release](https://github.com/dani-garcia/vaultwarden/releases/tag/1.37.4)
lists security fixes, including a high-severity organization member revocation
issue, and reverse-proxy trusted-address upgrade notes. Several linked advisory
details remain private; the release notes support updating, but do not establish
which organization-related paths are used here. Older advisories already fixed
in 1.37.0 were not counted as outstanding against 1.37.3.

**nginx:** 1.28.3 predates fixes in the current
[upstream advisory list](https://nginx.org/en/security_advisories.html), including
CVE-2026-42945 in rewrite processing. Use a maintained patched package;
upstream's latest listed fixes are in 1.30.6 / 1.31.7. Version matching is a
patch candidate, not proof every issue is reachable: rewrite/alias, HTTP/3,
AIO, and other affected features require configuration-specific review. The
selected-directive inspection of the active NUC config found a basic upgrade
map and a FastCGI include, not an active PHP/FastCGI handler or rewrite rule.

**OpenSSL:** deployed 3.6 libraries predate
[3.6.5 security fixes](https://www.openssl-library.org/news/vulnerabilities-3.6/index.html),
including CVE-2026-35189 affecting certificate-extension processing. Exposure
depends on the calling application and enabled protocol/features. Rebuild
consumers against updated dependencies and restart them; installing a separate
openssl executable will not update libraries embedded in old Nix closures.

## Containers and network exposure

| Container | Declared image | Pull policy | Verified state |
| --- | --- | --- | --- |
| Home Assistant | `ghcr.io/home-assistant/home-assistant:stable` | newer, at start | Service running since 25 September |
| ESPHome | `ghcr.io/esphome/esphome:stable` | newer, at start | Service running since 25 September |
| Stremio | `stremio/server:latest` | missing | Service running since 25 September |

`sudo -n podman ps` required a password. Image IDs, package inventories and
in-container TLS behavior therefore remain **unverified**. The Nixpkgs
`home-assistant` and `esphome` package versions are not these images' versions.
Floating tags are not evidence that an already running container is current.
Stremio's `missing` policy can retain an old local `latest` image indefinitely.
Updating the host lock file does not patch OCI filesystem layers. Home Assistant
also has privileged mode and host networking, increasing the impact of a
container compromise.

The evaluated global TCP allowances include 22, 53, 80, 443, 6052, 7881, 8091
and 8123; UDP includes 53, 67, 3478 and 5353. Runtime listeners for ESPHome
(6052), the analysis dashboard (8091), and Home Assistant (8123) bind all IPv4
interfaces. Scope intended management services to `vlan20` or the LAN address.
DNS listeners bind LAN/loopback, but DNS/DHCP firewall allowances are also global
and should be reviewed. The NUC's WAN address is private `192.168.1.247`;
Internet reachability depends on upstream-router forwarding and was not tested
from outside. A global allowance establishes exposure to the WAN segment,
not proof of public Internet reachability.

## Remediation and verification sequence

1. Refresh trust stores and runtime dependencies on all hosts. Move the NUC
   to a supported stable NixOS/Home Manager pair. NixOS 25.11 stopped security
   support on 30 June; 26.05 is supported through 31 December, per the
   [official release announcement](https://nixos.org/blog/announcements/2026/nixos-2605/).
   Keep `system.stateVersion` unchanged unless an individual migration requires
   a deliberate decision. Inspect the chosen package definitions and verify TLS
   behavior rather than assuming a channel refresh contains every fix.
2. Refresh independent application inputs and the NUC's Synapse/LiveKit
   dependencies. Verify database backups and review migration/proxy notes before
   deploying service upgrades. Rebuild/check first and retain router recovery access.
3. Inspect rootful OCI images without printing environment secrets; update
   tested versions/digests, recreate containers and test their own TLS clients.
4. Restrict LAN management services, refresh browser/add-on pins, and establish
   a regular reviewed update schedule. Automatic garbage collection is not
   security updating. Reboot after kernel updates and confirm `uname -r`.
5. Re-run the compromised-chain checks below in each relevant runtime and
   trust configuration. Every test must fail certificate verification while
   ordinary trusted HTTPS still succeeds. Confirm exact service binaries after
   restart, then verify application login, Matrix messaging, automation and backups.

Credential-free curl checks from the disclosure site:

```sh
curl --head --max-time 15 https://dv-g3b-emudhra.we-have-a-problem.com/
curl --head --max-time 15 https://dv-g3b-aaa-emudhra.we-have-a-problem.com/
curl --head --max-time 15 https://dv-g3b-noct-emudhra.we-have-a-problem.com/
curl --head --max-time 15 https://dv-g3b-aaa-noct-emudhra.we-have-a-problem.com/
curl --head --max-time 15 https://example.com/
```

For configurations that override trust files, test with those exact settings.
The known test hosts cover representative paths; review the disclosure's full
chain set when validating a comprehensive mitigation.

## Checks completed

- Compared flake input timestamps and evaluated relevant packages and service
  settings on all four hosts with `nix --store daemon eval --no-write-lock-file`.
- Inspected desktop and NUC deployed closures, running kernels, NUC service
  executable paths, listeners, container service start times and timers.
- Examined installed/default CA subjects and the locked Python packaging.
- Ran the credential-free TLS checks recorded above; sent no exploit payloads.
- `nix --store daemon flake check --no-write-lock-file --no-build
  git+file:///home/john/nixos-config` passed for all four configurations and the
  check derivation. This was evaluation only, not a build or a deployment test.

The explicit Git flake URL avoids an unrelated ignored tmux socket under the
OpenRig experiment tree when using `builtins.getFlake` with a filesystem path.
Origin was fetched; local main contained origin/main and was eleven commits
ahead at audit start. Findings describe this local baseline and the inspected
running systems, not an assumed remote deployment.
