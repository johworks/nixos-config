"""Regression checks for preserving writable Codex settings during activation."""

import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

import tomlkit


class ConfigureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.codex = self.home / ".codex"
        self.codex.mkdir()
        self.config = self.codex / "config.toml"

    def activate(self, servers):
        defaults = self.home / "defaults.toml"
        defaults.write_text(
            tomlkit.dumps(
                {
                    "default_permissions": "nix-workspace",
                    "approval_policy": "on-request",
                    "permissions": {"nix-workspace": {"extends": ":workspace"}},
                    "mcp_servers": servers,
                }
            )
        )
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("configure.py")),
                str(self.home),
                str(defaults),
            ],
            check=True,
        )
        return tomlkit.parse(self.config.read_text())

    def test_preserves_user_settings_and_is_idempotent(self):
        original = '# User preferences\nmodel = "chosen-model"\n\n[mcp_servers.personal]\nurl = "https://example.com/mcp"\n'
        self.config.write_text(original)
        declared = {
            "playwright": {
                "command": "/nix/store/example/bin/playwright-mcp",
                "args": ["--headless"],
            }
        }
        document = self.activate(declared)
        self.assertEqual(document["model"], "chosen-model")
        self.assertEqual(
            document["mcp_servers"]["personal"]["url"], "https://example.com/mcp"
        )
        self.assertIn("# User preferences", self.config.read_text())
        self.assertEqual(
            (self.codex / "config.toml.before-nix-permissions").read_text(), original
        )
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        before = self.config.stat().st_mtime_ns
        self.activate(declared)
        self.assertEqual(self.config.stat().st_mtime_ns, before)

    def test_reconciles_declared_fields_and_removal(self):
        self.activate(
            {"example": {"url": "https://example.com/mcp", "startup_timeout_sec": 30}}
        )
        document = tomlkit.parse(self.config.read_text())
        document["mcp_servers"]["example"]["enabled"] = False
        document["mcp_servers"]["example"]["oauth"] = {"client_id": "runtime-id"}
        document["mcp_servers"]["personal"] = {"command": "personal-server"}
        self.config.write_text(tomlkit.dumps(document))
        document = self.activate({"example": {"command": "local-server", "args": []}})
        server = document["mcp_servers"]["example"]
        self.assertNotIn("url", server)
        self.assertNotIn("startup_timeout_sec", server)
        self.assertFalse(server["enabled"])
        self.assertEqual(server["oauth"]["client_id"], "runtime-id")
        document = self.activate({})
        self.assertNotIn("example", document["mcp_servers"])
        self.assertEqual(
            document["mcp_servers"]["personal"]["command"], "personal-server"
        )
        self.assertEqual(
            json.loads((self.codex / "nix-managed-mcp-servers.json").read_text()), {}
        )

    def test_migrates_symlink_without_writing_through_it(self):
        source = self.home / "old-generated-config.toml"
        original = 'model = "chosen-model"\nsandbox_mode = "workspace-write"\n'
        source.write_text(original)
        source.chmod(0o444)
        self.config.symlink_to(source)
        document = self.activate({"playwright": {"command": "playwright-mcp"}})
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(source.read_text(), original)
        self.assertNotIn("sandbox_mode", document)
        self.assertEqual(document["model"], "chosen-model")


if __name__ == "__main__":
    unittest.main()
