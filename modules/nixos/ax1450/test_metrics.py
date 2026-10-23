"""Exercise vendor snapshot parsing and failed/atomic metric publication."""

import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import metrics


SNAPSHOT = """@uptime
260552.19 749227.09
@load
0.24 0.20 0.17 1/100 30237
@memory
MemTotal:         253672 kB
MemFree:           86688 kB
MemAvailable:      98764 kB
@netdev
Inter-| Receive | Transmit
wl0.1: 2571439704 3386416 0 0 0 0 0 0 3543306615 4358497 268 0 0 0 0 0
wl1.1: 187113844 1413678 0 0 0 0 0 0 2789764946 2134900 130 0 0 0 0 0
@bss 2g
up
@clients 2g
2
@rssi 2g
-26
-71
@chanspec 2g
2 (0x1002)
@noise 2g
-84
@counters 2g
counters_version 30
txframe 2136913 txbyte 2790093228 txretrans 297152 txlost 0 txfail 17512
@bss 5g
up
@clients 5g
0
@rssi 5g
@chanspec 5g
157/80 (0xe29b)
@noise 5g
-90
@counters 5g
txframe 4360489 txbyte 3543633499 txretrans 148005 txlost 0 txfail 246
"""


class MetricsTests(unittest.TestCase):
    def test_vendor_snapshot_and_direction(self):
        values = metrics.parse_snapshot(SNAPSHOT)
        self.assertEqual(values["ax1450_uptime_seconds"], 260552.19)
        self.assertEqual(values["ax1450_memory_available_bytes"], 98764 * 1024)
        self.assertEqual(
            values['ax1450_wifi_receive_bytes_total{band="2g"}'], 187113844
        )
        self.assertEqual(
            values['ax1450_wifi_transmit_bytes_total{band="2g"}'], 2789764946
        )
        self.assertEqual(values['ax1450_wifi_associated_clients{band="2g"}'], 2)
        self.assertEqual(values['ax1450_wifi_associated_clients{band="5g"}'], 0)
        self.assertEqual(values['ax1450_wifi_weakest_client_rssi_dbm{band="2g"}'], -71)
        self.assertNotIn('ax1450_wifi_weakest_client_rssi_dbm{band="5g"}', values)
        self.assertEqual(
            values['ax1450_wifi_transmit_retries_total{band="2g"}'], 297152
        )
        self.assertEqual(values['ax1450_wifi_transmit_failures_total{band="5g"}'], 246)

    def test_chanspec_formats(self):
        for text, channel, width in [
            ("36l (0x1824)", 36, 40),
            ("40u (0x1926)", 40, 40),
            ("165 (0xd0a5)", 165, 20),
        ]:
            with self.subTest(text=text):
                values = metrics.parse_snapshot(
                    SNAPSHOT.replace("157/80 (0xe29b)", text)
                )
                self.assertEqual(values['ax1450_wifi_channel{band="5g"}'], channel)
                self.assertEqual(
                    values['ax1450_wifi_channel_width_mhz{band="5g"}'], width
                )

    def test_invalid_optional_fields_are_absent(self):
        snapshot = (
            SNAPSHOT.replace("-90", "0")
            .replace("157/80 (0xe29b)", "driver error")
            .replace("@clients 5g\n0", "@clients 5g\nunavailable")
        )
        values = metrics.parse_snapshot(snapshot)
        for name in ["wifi_noise_dbm", "wifi_channel", "wifi_associated_clients"]:
            self.assertNotIn(f'ax1450_{name}{{band="5g"}}', values)
        self.assertEqual(values['ax1450_wifi_noise_dbm{band="2g"}'], -84)

    def test_disabled_radio_has_zero_clients_and_no_radio_readings(self):
        values = metrics.parse_snapshot(
            SNAPSHOT.replace("@bss 5g\nup", "@bss 5g\ndown")
        )
        samples = {k: v for k, v in values.items() if 'band="5g"' in k}
        self.assertEqual(samples, {'ax1450_wifi_associated_clients{band="5g"}': 0})

    def test_unavailable_radio_is_unknown(self):
        values = metrics.parse_snapshot(
            SNAPSHOT.replace("@bss 5g\nup", "@bss 5g\nunavailable")
        )
        self.assertFalse(any('band="5g"' in k for k in values))

    def test_bad_core_snapshot_is_rejected(self):
        for snapshot in [
            "",
            SNAPSHOT.replace("260552.19", "nan"),
            SNAPSHOT.replace("98764 kB", "999999 kB"),
            SNAPSHOT.replace("2789764946", "broken"),
            SNAPSHOT + "@uptime\n0\n",
        ]:
            with self.subTest(snapshot=snapshot[:30]):
                with self.assertRaises((ValueError, KeyError, IndexError)):
                    metrics.parse_snapshot(snapshot)

    def test_render_types_are_unique_and_no_identifying_labels(self):
        output = metrics.render(metrics.parse_snapshot(SNAPSHOT))
        self.assertEqual(
            output.count("# TYPE ax1450_wifi_receive_bytes_total counter\n"), 1
        )
        self.assertIn("# TYPE ax1450_uptime_seconds gauge\n", output)
        self.assertNotIn("mac=", output)
        self.assertNotIn("ssid=", output)

    def test_atomic_publish_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ap.prom"
            metrics.write_metrics(path, {"ax1450_metrics_collection_success": 1})
            original = path.read_text()
            replace = metrics.os.replace

            def observe(source, destination):
                self.assertEqual(path.read_text(), original)
                self.assertFalse(str(source).endswith(".prom"))
                replace(source, destination)

            with patch.object(metrics.os, "replace", side_effect=observe):
                metrics.write_metrics(path, {"ax1450_metrics_collection_success": 0})
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
            self.assertIn("ax1450_metrics_collection_success 0", path.read_text())
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_failed_collection_removes_old_samples_and_pins_ssh(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ap.prom"
            script = Path(directory) / "remote.sh"
            script.write_text("read-only snapshot script")
            argv = [
                "metrics.py",
                "--host",
                "192.168.10.161",
                "--port",
                "2222",
                "--key",
                "/private/key",
                "--known-hosts",
                "/pinned/hosts",
                "--remote-script",
                str(script),
                "--output",
                str(path),
            ]
            with patch.object(metrics.sys, "argv", argv):
                result = subprocess.CompletedProcess([], 0, SNAPSHOT, "")
                with patch.object(
                    metrics.subprocess, "run", return_value=result
                ) as run:
                    self.assertEqual(metrics.main(), 0)
                command = run.call_args.args[0]
                self.assertIn("StrictHostKeyChecking=yes", command)
                self.assertIn("UserKnownHostsFile=/pinned/hosts", command)
                self.assertEqual(command[-2:], ["/bin/sh", "-s"])
                self.assertEqual(run.call_args.kwargs["input"], script.read_text())
                self.assertEqual(run.call_args.kwargs["timeout"], 20)
                self.assertIn("ax1450_uptime_seconds", path.read_text())
                self.assertIn(
                    "ax1450_metrics_sample_timestamp_seconds", path.read_text()
                )
                errors = [
                    subprocess.TimeoutExpired(command, 20),
                    subprocess.CalledProcessError(
                        1, command, stderr="private vendor output"
                    ),
                    ValueError("private vendor output"),
                ]
                for error in errors:
                    with self.subTest(error=type(error).__name__):
                        stderr = io.StringIO()
                        with (
                            patch.object(metrics.subprocess, "run", side_effect=error),
                            contextlib.redirect_stderr(stderr),
                        ):
                            self.assertEqual(metrics.main(), 1)
                        output = path.read_text()
                        self.assertNotIn("ax1450_uptime_seconds", output)
                        self.assertNotIn(
                            "ax1450_metrics_sample_timestamp_seconds", output
                        )
                        self.assertIn("ax1450_metrics_collection_success 0", output)
                        self.assertNotIn("private vendor output", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
