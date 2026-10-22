"""Exercise the real reconcile script against a disposable mock vendor system.

Only absolute device paths and the fixed PATH are redirected. No router or
network is used. The Nix check runs BusyBox ash, matching the AP's shell.
"""

import base64
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

SSID = "TP-Link_2724"
PSK = "test-only-O'Brien$\\password"
DAY = "* mkdir -p /etc/ax1450; /usr/bin/nvrammanager -r /etc/ax1450/payload.b64 -p router-config; /usr/bin/openssl base64 -d -A -in /etc/ax1450/payload.b64 | tee /etc/ax1450/bootstrap.sh | /bin/sh #"
COMMANDS = {
    "uci",
    "nvrammanager",
    "openssl",
    "auto-reboot",
    "iptables",
    "nvram",
    "wl",
    "wifi",
    "lua",
    "ssh",
}


def scheduler(root):
    result = {}
    for line in (root / "etc/config/autoreboot").read_text().splitlines():
        fields = shlex.split(line)
        if fields and fields[0] == "option":
            result[fields[1]] = fields[2]
    return result


def mock_command(name, args):
    root = Path(os.environ["AX1450_TEST_ROOT"])
    state_path = root / "state.json"
    state = json.loads(state_path.read_text())
    state["calls"].append([name, *args])
    rc = 0
    if name == "uci":
        args = [arg for arg in args if arg != "-q"]
        if args[0] == "get":
            if args[1].startswith("autoreboot.reboot."):
                value = scheduler(root).get(args[1].rsplit(".", 1)[1])
            else:
                value = state["wifi"].get(args[1])
            if value is None:
                rc = 1
            else:
                print(value)
        elif args[0] == "batch":
            if state.get("fail") == "batch":
                rc = 1
            else:
                for line in sys.stdin.read().splitlines():
                    command, assignment = shlex.split(line)
                    assert command == "set"
                    key, value = assignment.split("=", 1)
                    if state.get("ignore") != key:
                        state["wifi"][key] = value
        elif args == ["commit", "wireless"]:
            rc = int(state.get("fail") == "commit")
        else:
            raise AssertionError(args)
    elif name == "nvrammanager":
        rc = int(state.get("fail") == "flash-read")
        if not rc:
            shutil.copyfile(root / "flash.b64", args[args.index("-r") + 1])
    elif name == "openssl":
        if "-in" in args:
            data = Path(args[args.index("-in") + 1]).read_bytes()
        else:
            data = sys.stdin.buffer.read()
        try:
            decoded = base64.b64decode(data, validate=True)
            if "-out" in args:
                Path(args[args.index("-out") + 1]).write_bytes(decoded)
            else:
                sys.stdout.buffer.write(decoded)
        except ValueError:
            rc = 1
    elif name == "auto-reboot":
        rc = int(state.get("fail") == "cron")
        if not rc:
            cron = root / "etc/crontabs/root"
            lines = [
                line
                for line in cron.read_text().splitlines()
                if "dut_auto_reboot" not in line
            ]
            config = scheduler(root)
            if state.get("fail") == "unsafe-cron":
                lines.append("11 3 * * * sh /usr/sbin/dut_auto_reboot")
            elif config["enable"] == "on" and config["cycle"] == "week":
                lines.append(f"11 3 * * {config['day']} sh /usr/sbin/dut_auto_reboot")
            cron.write_text("\n".join(lines) + "\n")
    elif name == "nvram":
        key = args[1]
        for sec, iface in [("wl03", "wl0.1"), ("wl13", "wl1.1")]:
            for suffix, option in [("ssid", "ssid"), ("wpa_psk", "psk_key")]:
                if key == f"{iface}_{suffix}":
                    print(state["runtime"][f"wireless.{sec}.{option}"])
    elif name == "wl":
        print("down" if state.get("fail") == "bss-down" else "up")
    elif name == "wifi":
        rc = int(state.get("fail") == "reload")
        if not rc and state.get("fail") != "silent-reload":
            state["runtime"] = state["wifi"].copy()
        # Make sure vendor output never leaks into the service journal.
        print(PSK)
    elif name == "lua":
        rc = int(state.get("fail") == "save")
        if not rc:
            state["persisted"] = {
                "scheduler": scheduler(root),
                "wifi": state["wifi"].copy(),
            }
        print(PSK)
    elif name == "ssh":
        state["ssh_stdin"] = sys.stdin.read()
    state_path.write_text(json.dumps(state))
    return rc


class ReconcileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in [
            "etc/config",
            "etc/crontabs",
            "etc/init.d",
            "tmp",
            "proc/123",
            "bin",
        ]:
            (self.root / directory).mkdir(parents=True)
        mock = self.root / "mock.py"
        mock.write_text(f"#!{sys.executable}\n" + Path(__file__).read_text())
        mock.chmod(0o700)
        for name in COMMANDS:
            (self.root / "bin" / name).symlink_to(mock)
        (self.root / "etc/init.d/auto-reboot").symlink_to(self.root / "bin/auto-reboot")
        self.bootstrap = (
            f"printf ran >> {shlex.quote(str(self.root / 'bootstrap-ran'))}\n"
        )
        self.sha = hashlib.sha256(self.bootstrap.encode()).hexdigest()
        self.set_payload(self.bootstrap)
        (self.root / "tmp/ax1450-root.pid").write_text("123\n")
        wifi = {}
        for sec, iface in [("wl03", "wl0.1"), ("wl13", "wl1.1")]:
            wifi.update(
                {
                    f"wireless.{sec}.ssid": SSID,
                    f"wireless.{sec}.psk_key": PSK,
                    f"wireless.{sec}.ifname": iface,
                }
            )
        self.write_state({"wifi": wifi, "runtime": wifi.copy(), "calls": []})
        self.set_scheduler()
        self.cron = self.root / "etc/crontabs/root"
        self.cron.write_text(f"11 3 * * {DAY} sh /usr/sbin/dut_auto_reboot\n")

    def state(self):
        return json.loads((self.root / "state.json").read_text())

    def write_state(self, state):
        (self.root / "state.json").write_text(json.dumps(state))

    def update_state(self, **changes):
        self.write_state(self.state() | changes)

    def set_payload(self, text):
        (self.root / "flash.b64").write_bytes(base64.b64encode(text.encode()))

    def set_scheduler(self, *, indent="    ", **changes):
        settings = {
            "enable": "on",
            "cycle": "week",
            "time": "03:11",
            "day": DAY,
        } | changes
        text = "config default 'reboot'\n"
        text += "".join(
            f"{indent}option         {key} {shlex.quote(value)}\n"
            for key, value in settings.items()
        )
        (self.root / "etc/config/autoreboot").write_text(text)

    def run_reconcile(self, *, ssid=SSID, psk=PSK):
        script_path = Path(__file__).with_name("reconcile-remote.sh")
        if not script_path.exists():
            script_path = Path("reconcile-remote.sh")
        script = script_path.read_text()
        for command in ["nvrammanager", "openssl", "lua"]:
            script = script.replace(f"/usr/bin/{command}", f"@ROOT@/bin/{command}")
        script = script.replace("/usr/sbin/iptables", "@ROOT@/bin/iptables")
        for directory in ["/etc/", "/tmp/", "/proc/"]:
            script = script.replace(directory, "@ROOT@" + directory)
        script = script.replace("@ROOT@", str(self.root))
        script = script.replace(
            "export PATH=/sbin:/usr/sbin:/bin:/usr/bin",
            f"export PATH={self.root}/bin:$PATH",
        )
        values = {
            "PSK_B64": base64.b64encode(psk.encode()).decode(),
            "SSID": ssid,
            "DAY_VALUE": DAY,
            "EXPECTED_SHA": self.sha,
            "PORT": "2222",
            "MANAGER_IP": "192.168.10.1",
        }
        prefix = "".join(
            f"{key}={shlex.quote(value)}\n" for key, value in values.items()
        )
        result = subprocess.run(
            [os.environ.get("AX1450_TEST_SHELL", "/bin/sh"), "-s"],
            input=prefix + script,
            text=True,
            capture_output=True,
            env=os.environ | {"AX1450_TEST_ROOT": str(self.root)},
            timeout=30,
        )
        self.assertNotIn(psk, result.stdout + result.stderr)
        self.assertEqual(list((self.root / "tmp").glob("ax1450-reconcile.*")), [])
        return result

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("OK: persistence verified, Wi-Fi converged", result.stdout)

    def assert_failure(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("OK:", result.stdout)

    def drift_wifi(self):
        state = self.state()
        state["wifi"]["wireless.wl03.psk_key"] = "old-password"
        state["runtime"] = state["wifi"].copy()
        self.write_state(state)

    def test_noop_does_not_reload_or_write_flash(self):
        self.assert_success(self.run_reconcile())
        self.assert_success(self.run_reconcile())
        self.assertFalse(
            {"wifi", "lua", "auto-reboot"} & {call[0] for call in self.state()["calls"]}
        )

    def test_repairs_scheduler_with_vendor_whitespace(self):
        for indent in ["    ", "", "\t"]:
            with self.subTest(indent=indent):
                self.set_scheduler(
                    indent=indent, day="Mon", enable="off", cycle="day", time="03:00"
                )
                (self.root / "tmp/.uci").mkdir(exist_ok=True)
                (self.root / "tmp/.uci/autoreboot").touch()
                self.assert_success(self.run_reconcile())
                self.assertEqual(
                    self.state()["persisted"]["scheduler"], scheduler(self.root)
                )
                self.assertEqual(scheduler(self.root)["day"], DAY)
                self.assertFalse((self.root / "tmp/.uci/autoreboot").exists())

    def test_repairs_each_scheduler_field_with_intact_day(self):
        for field, value in [("enable", "off"), ("cycle", "day"), ("time", "02:00")]:
            with self.subTest(field=field):
                self.set_scheduler(**{field: value})
                self.assert_success(self.run_reconcile())
                self.assertEqual(
                    scheduler(self.root)[field],
                    {"enable": "on", "cycle": "week", "time": "03:11"}[field],
                )

    def test_repairs_missing_unsafe_and_duplicate_cron(self):
        line = f"11 3 * * {DAY} sh /usr/sbin/dut_auto_reboot\n"
        for content in ["", "11 3 * * * sh /usr/sbin/dut_auto_reboot\n", line + line]:
            with self.subTest(content=content):
                self.cron.write_text(content)
                self.assert_success(self.run_reconcile())
                self.assertEqual(
                    [
                        x
                        for x in self.cron.read_text().splitlines()
                        if "dut_auto_reboot" in x
                    ],
                    [line.strip()],
                )

    def test_rejects_failed_or_unsafe_cron_regeneration(self):
        for failure in ["cron", "unsafe-cron"]:
            with self.subTest(failure=failure):
                self.update_state(fail=failure)
                self.cron.write_text("")
                self.assert_failure(self.run_reconcile())

    def test_mismatched_payload_never_executes_or_replaces_bootstrap(self):
        sentinel = self.root / "malicious-ran"
        self.set_payload(f"touch {shlex.quote(str(sentinel))}\n")
        installed = self.root / "etc/ax1450/bootstrap.sh"
        installed.parent.mkdir()
        installed.write_text("previous verified bootstrap")
        self.assert_failure(self.run_reconcile())
        self.assertFalse(sentinel.exists())
        self.assertFalse((self.root / "bootstrap-ran").exists())
        self.assertEqual(installed.read_text(), "previous verified bootstrap")

    def test_flash_read_and_decode_failure_never_execute(self):
        self.update_state(fail="flash-read")
        self.assert_failure(self.run_reconcile())
        self.update_state(fail="")
        (self.root / "flash.b64").write_text("invalid base64!")
        self.assert_failure(self.run_reconcile())
        self.assertFalse((self.root / "bootstrap-ran").exists())

    def test_psk_drift_converges_both_bands_and_quotes_safely(self):
        self.drift_wifi()
        ssid = "Lab O'Brien $test \\literal"
        self.assert_success(self.run_reconcile(ssid=ssid))
        state = self.state()
        for sec in ["wl03", "wl13"]:
            for settings in [
                state["wifi"],
                state["runtime"],
                state["persisted"]["wifi"],
            ]:
                self.assertEqual(settings[f"wireless.{sec}.psk_key"], PSK)
                self.assertEqual(settings[f"wireless.{sec}.ssid"], ssid)
        self.assertNotIn(PSK, json.dumps(state["calls"]))

    def test_wifi_failures_are_reported_and_retried(self):
        for failure in [
            "batch",
            "commit",
            "reload",
            "silent-reload",
            "bss-down",
            "save",
        ]:
            with self.subTest(failure=failure):
                self.drift_wifi()
                self.update_state(fail=failure)
                self.assert_failure(self.run_reconcile())
                self.assertTrue((self.root / "etc/ax1450/save-pending").exists())
                self.update_state(fail="")
                self.assert_success(self.run_reconcile())
                self.assertEqual(
                    self.state()["persisted"]["wifi"]["wireless.wl03.psk_key"], PSK
                )
                self.assertFalse((self.root / "etc/ax1450/save-pending").exists())

    def test_rejects_psk_that_was_not_set(self):
        self.drift_wifi()
        self.update_state(ignore="wireless.wl03.psk_key")
        self.assert_failure(self.run_reconcile())
        self.assertNotIn("wifi", [call[0] for call in self.state()["calls"]])

    def test_failed_save_retries_without_wifi_reload(self):
        self.drift_wifi()
        self.update_state(fail="save")
        self.assert_failure(self.run_reconcile())
        self.update_state(fail="", calls=[])
        self.assert_success(self.run_reconcile())
        self.assertNotIn("wifi", [call[0] for call in self.state()["calls"]])

    def test_scheduler_save_failure_is_retried(self):
        self.set_scheduler(enable="off")
        self.update_state(fail="save")
        self.assert_failure(self.run_reconcile())
        self.update_state(fail="", calls=[])
        self.assert_success(self.run_reconcile())
        self.assertIn("lua", [call[0] for call in self.state()["calls"]])

    def test_invalid_psk_does_not_change_device(self):
        self.assert_failure(self.run_reconcile(psk="short"))
        self.assertFalse((self.root / "bootstrap-ran").exists())

    @unittest.skipUnless(
        os.environ.get("AX1450_TEST_WRAPPER"), "Nix-built wrapper required"
    )
    def test_actual_nix_wrapper_sends_secret_only_over_stdin(self):
        wrapper = Path(os.environ["AX1450_TEST_WRAPPER"]).read_text()
        secret = self.root / "password"
        secret.write_text(PSK)
        wrapper = wrapper.replace("/run/secrets/ax1450_wifi_psk", str(secret))
        wrapper = wrapper.replace(
            "ssh -F /dev/null", f"{self.root}/bin/ssh -F /dev/null"
        )
        env = os.environ | {"AX1450_TEST_ROOT": str(self.root)}
        result = subprocess.run(
            ["bash", "-c", wrapper], capture_output=True, text=True, env=env, timeout=30
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        state = self.state()
        encoded = base64.b64encode(PSK.encode()).decode()
        self.assertNotIn(PSK, json.dumps(state["calls"]))
        self.assertNotIn(encoded, json.dumps(state["calls"]))
        self.assertTrue(state["ssh_stdin"].startswith(f"PSK_B64={encoded}\n"))
        self.assertIn("wifi_config_matches", state["ssh_stdin"])
        self.assertEqual(state["calls"][-1][-2:], ["/bin/sh", "-s"])


if __name__ == "__main__":
    command = Path(sys.argv[0]).name
    if command in COMMANDS:
        sys.exit(mock_command(command, sys.argv[1:]))
    unittest.main()
