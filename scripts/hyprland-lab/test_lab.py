"""Checks for boundaries that must hold before a guest is available."""

import argparse
import json
import shlex
import socket
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from lab import Lab


class LabTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.state = Path(self.temporary.name)
        self.lab = Lab(argparse.Namespace(state=str(self.state), flake="."))
        self.directory = self.state / "runs" / "test"
        self.directory.mkdir(parents=True)
        self.lab.current.symlink_to(self.directory)
        (self.directory / "run.json").write_text('{"port":2222}')

    def test_refuses_state_accessible_to_other_users(self):
        self.state.chmod(0o755)
        with self.assertRaisesRegex(RuntimeError, "0700"):
            Lab(argparse.Namespace(state=str(self.state)))

    def test_reset_retains_all_evidence(self):
        (self.directory / "disk.qcow2").write_bytes(b"experimental data")
        (self.directory / "report.json").write_text('{"passed":false}')
        with patch.object(self.lab, "stop"):
            self.lab.reset()
        self.assertFalse(self.lab.current.is_symlink())
        self.assertEqual(
            (self.directory / "disk.qcow2").read_bytes(), b"experimental data"
        )
        self.assertTrue((self.directory / "report.json").exists())

    def test_reset_keeps_current_when_stop_fails(self):
        with (
            patch.object(self.lab, "stop", side_effect=RuntimeError("still running")),
            self.assertRaises(RuntimeError),
        ):
            self.lab.reset()
        self.assertTrue(self.lab.current.is_symlink())

    def test_guest_shell_arguments_are_literal_and_host_key_is_pinned(self):
        dangerous = ["printf", "%s", "$(touch /tmp/unwanted)\n`id` ' quoted"]
        with patch("lab.run") as execute:
            self.lab.ssh(dangerous, capture=True)
        argv = execute.call_args.args[0]
        self.assertEqual(shlex.split(argv[-1]), dangerous)
        self.assertIn("StrictHostKeyChecking=yes", argv)
        self.assertIn("ForwardAgent=no", argv)
        self.assertIn("/dev/null", argv)

    def qmp_server(self, *, fail=False):
        ready = threading.Event()

        def serve():
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(self.directory / "qmp.sock"))
                server.listen()
                ready.set()
                connection, _ = server.accept()
                with connection, connection.makefile("rwb", buffering=0) as stream:
                    stream.write(b'{"QMP":{"version":{},"capabilities":[]}}\r\n')
                    for index in range(2):
                        request = json.loads(stream.readline())
                        stream.write(b'{"event":"RESUME"}\r\n')
                        result = {"id": request["id"], "return": {"status": "running"}}
                        if index == 1 and fail:
                            result = {
                                "id": request["id"],
                                "error": {"desc": "bad command"},
                            }
                        stream.write(json.dumps(result).encode() + b"\r\n")

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        self.assertTrue(ready.wait(2))
        self.addCleanup(thread.join, 2)

    def test_qmp_ignores_interleaved_events(self):
        self.qmp_server()
        self.assertEqual(self.lab.qmp("query-status"), {"status": "running"})

    def test_qmp_propagates_errors(self):
        self.qmp_server(fail=True)
        with self.assertRaisesRegex(RuntimeError, "bad command"):
            self.lab.qmp("invalid")


if __name__ == "__main__":
    unittest.main()
