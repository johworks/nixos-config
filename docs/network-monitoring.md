# NUC network monitoring

Open <http://192.168.10.1:3000> from the LAN. Grafana opens **Home Network
Health** without a login, with anonymous Viewer access. Admin creation, basic
authentication, sign-up, and the login form are disabled. This deliberately
trusts LAN clients with read access to all collected metrics. There is no public
reverse proxy or Cloud dependency.

`hosts/nuc/router-monitoring.nix` enables the native NixOS services, provisions
the Prometheus data source and dashboard provider, and defines the probes.
`hosts/nuc/dashboards/home-network-health.json` defines the dashboard. Both are
authoritative: dashboard and data-source edits cannot be saved in the GUI.
Change the files and rebuild to update the deployment.

## Collection and retention

- Node Exporter collects interface counters, CPU, memory, hardware temperatures,
  connection tracking, and selected systemd service states every 15 seconds.
- Blackbox Exporter probes Cloudflare and Quad9 with IPv4 ICMP, and resolves
  `example.com` through the NUC's local DNS server every 15 seconds. Successful
  DNS probes require an A record in the response; cached answers count.
- Prometheus stores up to 30 days of metrics, or 2 GB of time-series blocks,
  whichever limit is reached first. The size limit excludes WAL and head data,
  so actual disk usage can exceed 2 GB.
- Persistent service state uses the NixOS module defaults under
  `/var/lib/prometheus2` and `/var/lib/grafana`. Rebuilding preserves history.
- `ax1450-metrics.timer` collects a read-only AP snapshot over the existing
  pinned, key-only SSH connection every 30 seconds. Node Exporter's textfile
  collector reads `/var/lib/ax1450-metrics/ax1450.prom`; no new AP listener is
  opened. The collector reads only the SSH key, not the Wi-Fi password.

Grafana listens only on `192.168.10.1:3000`; the firewall opens that port only on
LAN interface `vlan20`. Prometheus (`9090`), Node Exporter (`9100`), and Blackbox
Exporter (`9115`) listen only on `127.0.0.1`, with no firewall openings.
The NixOS Blackbox Exporter module grants the ambient capability needed for
ICMP; the host permits `CAP_NET_RAW` in its capability bounding set as well.

## Reading the dashboard

WAN traffic uses `vlan10` alone. LAN `vlan20` and trunk `enp1s0` counters are
shown separately for errors and drops, never summed into bandwidth totals.
Traffic includes both routed clients and the NUC's own activity. Same-LAN
traffic can stay on the switch; this dashboard does not account per device.

Latency and bandwidth share a time range so you can investigate latency under
load. Probe failures are sampled connectivity failures, not a continuous
packet-loss measurement. Failed latency probes leave gaps. Missing metrics
are unknown, not healthy; an outage of this NUC also stops its monitoring.
Interface drop counters do not include a separate breakdown of CAKE shaping.

Allow about a minute after first deployment for rate graphs to populate. The
rolling 24-hour traffic totals are estimates from available samples; a full
day of coverage requires a full day of collection. Temperature is the highest
available hardware sensor reading, rather than a specific CPU sensor.

## AP measurements

The dashboard includes AP uptime, one-minute load and memory use, plus
per-band traffic, associated-client counts, radio retransmissions/failures,
weakest-client RSSI, noise floor, primary channel and operating width. Binary
reachability, service-state and collector-state panels have been removed;
the underlying diagnostics and probes remain available in Prometheus.

Traffic and client counts cover the main SSIDs (`wl1.1` for 2.4 GHz,
`wl0.1` for 5 GHz), excluding guest interfaces. Transmit means AP to clients;
receive means clients to AP. Radio retransmission/failure counters include
other traffic on the same radio. Their rates are not application packet
loss percentages. `rate()` handles counter resets after reboot or reload.
The Broadcom channel-idle score is not graphed because its scaling has not
been verified for this firmware.

RSSI is measured at the AP, with only the weakest valid reading per band
exported. It is absent when there are no readable associated clients.
Device MAC addresses, names, SSIDs and credentials are not metric labels.
A disabled BSS reports zero clients; unavailable readings remain absent.
Load average is a count of runnable/waiting work, not CPU utilization.

Failed collection atomically replaces the old sample with failure diagnostics,
removing previous AP readings. Every AP query also requires successful
collection and a snapshot timestamp less than 90 seconds old. This prevents
a stopped timer or leftover textfile after reboot from looking current.
AP charts leave gaps for unavailable data. Root SSH can remain unavailable
until the AP's 03:11 recovery schedule fires after an AP reboot.

Enable collection with `services.ax1450.metrics.enable = true`; the NUC
configuration already does so. Implementation lives in
`modules/nixos/ax1450/{metrics.nix,metrics.py,collect-remote.sh}`.
The Python collector is bounded to 20 seconds, with a 25-second systemd limit.
No Wi-Fi reload, settings commit, flash write or AP reboot occurs during
collection. The [Node Exporter textfile collector](https://github.com/prometheus/node_exporter#textfile-collector)
reads atomic `.prom` files; freshness is a separate metric, not a custom
Prometheus sample timestamp.

```sh
systemctl status ax1450-metrics.timer
journalctl -u ax1450-metrics.service -n 20 --no-pager
cat /var/lib/ax1450-metrics/ax1450.prom
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=ax1450_metrics_collection_success'
```

## Validation and troubleshooting

```sh
nix --store daemon flake check --no-write-lock-file
nix --store daemon build --no-write-lock-file .#nixosConfigurations.nuc.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#nuc
systemctl status grafana prometheus prometheus-node-exporter prometheus-blackbox-exporter
curl -fsS http://192.168.10.1:3000/api/health
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=probe_success'
```

For individual probe failures:

```sh
curl -fsS 'http://127.0.0.1:9115/probe?module=icmp_ipv4&target=1.1.1.1&debug=true'
curl -fsS 'http://127.0.0.1:9115/probe?module=dns_local&target=127.0.0.1:53&debug=true'
journalctl -u grafana -u prometheus -u prometheus-node-exporter -u prometheus-blackbox-exporter
```

No notification delivery or per-device traffic capture is configured. Those can
be added later without changing this dashboard's collection architecture.
