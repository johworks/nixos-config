"""Collect an AX1450 snapshot over pinned SSH and atomically publish metrics."""

import argparse
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

HELP = {
    "uptime_seconds": "AP uptime in seconds.",
    "load1": "AP one-minute load average.",
    "memory_total_bytes": "AP total memory in bytes.",
    "memory_available_bytes": "AP available memory including reclaimable cache in bytes.",
    "wifi_receive_bytes_total": "Bytes received by the AP main-SSID interface from clients.",
    "wifi_transmit_bytes_total": "Bytes transmitted by the AP main-SSID interface to clients.",
    "wifi_associated_clients": "Clients associated with the main BSS.",
    "wifi_noise_dbm": "Radio noise floor in dBm as reported by the AP.",
    "wifi_weakest_client_rssi_dbm": "Weakest valid associated-client RSSI measured at the AP in dBm.",
    "wifi_channel": "Primary channel of an active radio.",
    "wifi_channel_width_mhz": "Operating channel width in MHz.",
    "wifi_transmit_retries_total": "Broadcom radio transmit retransmission counter.",
    "wifi_transmit_failures_total": "Broadcom radio failed-transmission counter.",
    "metrics_sample_timestamp_seconds": "Unix time of the successful AP snapshot.",
    "metrics_collection_success": "Whether the latest AP snapshot was collected successfully.",
    "metrics_collection_duration_seconds": "Duration of the AP collection attempt in seconds.",
}


def number(text, minimum=0, maximum=math.inf):
    value = float(text)
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError("invalid numeric sample")
    return value


def parse_snapshot(snapshot):
    blocks = {}
    current = None
    for line in snapshot.splitlines():
        if line.startswith("@"):
            current = line[1:]
            if current in blocks:
                raise ValueError("duplicate snapshot block")
            blocks[current] = []
        elif current is not None and line.strip():
            blocks[current].append(line.strip())

    metrics = {}

    def add(name, value, band=None):
        labels = f'{{band="{band}"}}' if band else ""
        metrics[f"ax1450_{name}{labels}"] = value

    add("uptime_seconds", number(blocks["uptime"][0].split()[0]))
    add("load1", number(blocks["load"][0].split()[0]))
    memory = {}
    for line in blocks["memory"]:
        match = re.fullmatch(r"(\w+):\s+(\d+) kB", line)
        if match:
            memory[match[1]] = int(match[2]) * 1024
    total = memory["MemTotal"]
    if total <= 0 or not 0 <= memory["MemAvailable"] <= total:
        raise ValueError("invalid memory sample")
    add("memory_total_bytes", total)
    add("memory_available_bytes", memory["MemAvailable"])

    interfaces = {}
    for line in blocks["netdev"]:
        if ":" not in line:
            continue
        name, values = line.split(":", 1)
        if name.strip() in {"wl0.1", "wl1.1"}:
            fields = values.split()
            if len(fields) != 16 or not all(x.isdecimal() for x in fields):
                raise ValueError("invalid interface counters")
            interfaces[name.strip()] = [int(x) for x in fields]

    for band, iface in [("2g", "wl1.1"), ("5g", "wl0.1")]:
        bss = blocks.get(f"bss {band}", [])
        if bss == ["down"]:
            add("wifi_associated_clients", 0, band)
            continue
        if bss != ["up"]:
            continue
        if iface in interfaces:
            values = interfaces[iface]
            add("wifi_receive_bytes_total", values[0], band)
            add("wifi_transmit_bytes_total", values[8], band)
        clients = blocks.get(f"clients {band}", [])
        if len(clients) == 1 and clients[0].isdecimal():
            add("wifi_associated_clients", int(clients[0]), band)

        # Unsupported or malformed optional driver readings stay absent.
        for block, name in [
            ("noise", "wifi_noise_dbm"),
            ("rssi", "wifi_weakest_client_rssi_dbm"),
        ]:
            readings = []
            for text in blocks.get(f"{block} {band}", []):
                try:
                    readings.append(number(text, -127, -1))
                except ValueError:
                    pass
            if readings:
                add(name, min(readings), band)

        chanspec = blocks.get(f"chanspec {band}", [])
        if len(chanspec) == 1:
            match = re.fullmatch(
                r"(\d+)(?:/(20|40|80)|([lu]))?\s+\(0x[0-9a-fA-F]+\)", chanspec[0]
            )
            if match:
                channel = int(match[1])
                allowed = (
                    range(1, 12)
                    if band == "2g"
                    else [36, 40, 44, 48, 149, 153, 157, 161, 165]
                )
                if channel in allowed:
                    add("wifi_channel", channel, band)
                    add(
                        "wifi_channel_width_mhz",
                        int(match[2] or (40 if match[3] else 20)),
                        band,
                    )
        counters = "\n".join(blocks.get(f"counters {band}", []))
        for field, name in [
            ("txretrans", "wifi_transmit_retries_total"),
            ("txfail", "wifi_transmit_failures_total"),
        ]:
            match = re.search(rf"\b{field}\s+(\d+)\b", counters)
            if match:
                add(name, int(match[1]), band)
    return metrics


def render(metrics):
    lines = []
    families = set()
    for sample, value in sorted(metrics.items()):
        name = sample.split("{", 1)[0]
        # TYPE appears once per family, even with multiple band labels.
        if name not in families:
            kind = "counter" if name.endswith("_total") else "gauge"
            lines.append(f"# HELP {name} {HELP[name.removeprefix('ax1450_')]}")
            lines.append(f"# TYPE {name} {kind}")
            families.add(name)
        lines.append(f"{sample} {value}")
    return "\n".join(lines) + "\n"


def write_metrics(path, metrics):
    # Temporary names do not end in .prom, so node exporter cannot scrape
    # half a sample. Replace the old file even when collection fails.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(render(metrics))
            handle.flush()
            os.fchmod(handle.fileno(), 0o644)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--key", type=Path, required=True)
    parser.add_argument("--known-hosts", type=Path, required=True)
    parser.add_argument("--remote-script", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    command = [
        "ssh",
        "-F",
        "/dev/null",
        "-i",
        str(args.key),
        "-o",
        "BatchMode=yes",
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        f"UserKnownHostsFile={args.known_hosts}",
        "-o",
        "StrictHostKeyChecking=yes",
        "-o",
        "HostKeyAlgorithms=+ssh-rsa",
        "-o",
        "PubkeyAcceptedAlgorithms=+ssh-rsa",
        "-o",
        "ConnectTimeout=5",
        "-o",
        "ServerAliveInterval=5",
        "-o",
        "ServerAliveCountMax=1",
        "-p",
        str(args.port),
        f"root@{args.host}",
        "/bin/sh",
        "-s",
    ]
    start = time.monotonic()
    metrics = {}
    success = False
    try:
        result = subprocess.run(
            command,
            input=args.remote_script.read_text(),
            capture_output=True,
            text=True,
            timeout=20,
            check=True,
        )
        metrics = parse_snapshot(result.stdout)
        metrics["ax1450_metrics_sample_timestamp_seconds"] = time.time()
        success = True
    except (
        OSError,
        subprocess.SubprocessError,
        ValueError,
        KeyError,
        IndexError,
    ) as error:
        # Driver output and SSH stderr stay out of the journal.
        print(
            f"AX1450 metrics collection failed ({type(error).__name__})",
            file=sys.stderr,
        )
    metrics["ax1450_metrics_collection_success"] = int(success)
    metrics["ax1450_metrics_collection_duration_seconds"] = time.monotonic() - start
    write_metrics(args.output, metrics)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
