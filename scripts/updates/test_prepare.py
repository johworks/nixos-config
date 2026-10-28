import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest
from unittest.mock import patch

import prepare


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repo = self.root / "source"
        self.repo.mkdir()
        self.git("init", "-b", "main")
        (self.repo / "flake.lock").write_text('{"nodes":{},"root":"root","version":7}')
        (self.repo / "value").write_text("healthy")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@localhost",
                 "-c", "commit.gpgsign=false", "commit", "-m", "Fixture")
        self.base = self.git("rev-parse", "HEAD").strip()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        system = os.environ.get("TEST_SYSTEM", str(Path("/run/current-system").resolve()))
        self.write_program("nix", f'''
import json, os, pathlib, sys
assert 'OPENAI_API_KEY' not in os.environ
assert 'SSH_AUTH_SOCK' not in os.environ
p=pathlib.Path.cwd()
if 'update' in sys.argv:
    lock=json.loads((p/'flake.lock').read_text()); lock['updated']=True
    (p/'flake.lock').write_text(json.dumps(lock))
if 'check' in sys.argv and (p/'value').read_text() != 'healthy':
    print('Expected value file to contain healthy'); sys.exit(1)
if 'build' in sys.argv:
    root=pathlib.Path(sys.argv[sys.argv.index('--out-link')+1])
    root.unlink(missing_ok=True); root.symlink_to({json.dumps(system)})
''')
        self.write_program("nixfmt", "import sys\nsys.exit(0)\n")
        self.write_program("codex", '''
import pathlib, sys
assert '--ignore-user-config' in sys.argv and '--ignore-rules' in sys.argv
assert any('network={enabled=false}' in arg for arg in sys.argv)
assert 'Do not activate/reboot' in sys.stdin.read()
root=pathlib.Path(sys.argv[sys.argv.index('-C')+1]); (root/'value').write_text('healthy')
''')
        self.environment = patch.dict(os.environ, {
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "OPENAI_API_KEY": "TEST-ONLY-NOT-A-SECRET", "SSH_AUTH_SOCK": "/test-only",
        })
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.temporary.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.repo), *arguments],
                                       stderr=subprocess.DEVNULL, text=True)

    def write_program(self, name, body):
        path = self.bin / name
        path.write_text("#!" + sys.executable + "\n" + body)
        path.chmod(0o755)

    def arguments(self, **updates):
        args = dict(repo=self.repo, state_dir=self.root / "state", base="main",
                    timeout=30, host=["nuc"], no_refresh=True, repair_attempts=0, codex="codex",
                    notify_signal=False, signal_key=self.root / "unused-test-key")
        args.update(updates)
        return argparse.Namespace(**args)

    def run_preparation(self, **updates):
        job = prepare.Preparation(self.arguments(**updates))
        with contextlib.redirect_stdout(io.StringIO()):
            result = job.execute()
        return result, job, json.loads((job.run / "report.json").read_text())

    def test_success_is_immutable_and_source_is_untouched(self):
        result, job, report = self.run_preparation(no_refresh=False)
        self.assertEqual(result, 0)
        self.assertNotEqual(report["candidate_commit"], self.base)
        self.assertEqual(report["lock_sha256"], prepare.digest(job.candidate / "flake.lock"))
        self.assertEqual(report["hosts"]["nuc"]["status"], "built")
        self.assertEqual(self.git("rev-parse", "HEAD").strip(), self.base)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertNotIn("updated", (self.repo / "flake.lock").read_text())
        self.assertEqual(report["temporary_fix_review"]["status"], "inventory missing; operator review required")

    def test_temporary_fix_inventory_is_reported_as_unreviewed(self):
        (self.repo / "docs").mkdir()
        (self.repo / "docs/temporary-fixes.md").write_text("Review the tracked fixes.\n")
        self.git("add", "docs/temporary-fixes.md")
        self.git("-c", "user.name=Test", "-c", "user.email=test@localhost",
                 "-c", "commit.gpgsign=false", "commit", "-m", "Inventory")
        result, _, report = self.run_preparation()
        self.assertEqual(result, 0)
        self.assertEqual(report["temporary_fix_review"], {
            "inventory": "docs/temporary-fixes.md",
            "status": "not reviewed; operator review required",
        })

    def test_repair_is_checked_again_and_preserves_failure_log(self):
        (self.repo / "value").write_text("broken")
        self.git("add", "value")
        self.git("-c", "user.name=Test", "-c", "user.email=test@localhost",
                 "-c", "commit.gpgsign=false", "commit", "-m", "Broken fixture")
        result, job, report = self.run_preparation(repair_attempts=1)
        self.assertEqual(result, 0)
        self.assertEqual(report["repair_attempts"], 1)
        checks = [step for step in report["steps"] if step["name"] == "flake-check"]
        self.assertEqual([step["exit_code"] for step in checks], [1, 0])
        self.assertIn("Expected value", (job.run / checks[0]["log"]).read_text())
        self.assertEqual((self.repo / "value").read_text(), "broken")

    def test_retries_are_bounded(self):
        self.write_program("nix", "import sys\nsys.exit(1 if 'check' in sys.argv else 0)")
        self.write_program("codex", "import sys\nsys.stdin.read()")
        result, _, report = self.run_preparation(repair_attempts=2)
        self.assertEqual(result, 1)
        self.assertEqual(report["repair_attempts"], 2)
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["hosts"], {})

    def test_report_and_original_checkout_are_outside_agent_permissions(self):
        options = prepare.repair_options(self.repo, "codex")
        raw = next(arg.split("=", 1)[1] for arg in options if arg.startswith("permissions.update-repair="))
        policy = tomllib.loads("policy=" + raw)["policy"]
        self.assertFalse(policy["network"]["enabled"])
        self.assertEqual(policy["filesystem"][":root"], "deny")
        self.assertEqual(policy["filesystem"][":slash_tmp"], "deny")
        self.assertNotIn(str(Path.home() / ".codex"), policy["filesystem"])
        self.assertIn('approval_policy="never"', options)

    def test_build_environment_does_not_carry_credentials(self):
        env = prepare.clean_environment(self.root / "build-home")
        self.assertNotIn("OPENAI_API_KEY", env)
        self.assertNotIn("SSH_AUTH_SOCK", env)
        self.assertEqual(env["HOME"], str(self.root / "build-home"))

    def test_private_state_is_required(self):
        state = self.root / "public-state"
        state.mkdir(mode=0o755)
        with self.assertRaises(ValueError):
            prepare.Preparation(self.arguments(state_dir=state))

    def test_parallel_job_is_refused(self):
        first = prepare.Preparation(self.arguments())
        try:
            with self.assertRaises(BlockingIOError):
                prepare.Preparation(self.arguments())
        finally:
            first.lock.close()

    def test_timeout_kills_child_and_records_failure(self):
        job = prepare.Preparation(self.arguments())
        before = time.monotonic()
        try:
            with self.assertRaises(subprocess.TimeoutExpired):
                job.step("timeout", [sys.executable, "-c", "import time; time.sleep(60)"], timeout=0.03)
            self.assertLess(time.monotonic() - before, 2)
            self.assertTrue(job.report["steps"][-1]["interrupted"])
            self.assertNotEqual(job.report["steps"][-1]["exit_code"], 0)
        finally:
            job.lock.close()

    def test_failed_notification_keeps_built_report_and_returns_failure(self):
        self.write_program("ssh", "import sys\nsys.stdin.read(); sys.exit(1)")
        result, _, report = self.run_preparation(notify_signal=True)
        self.assertEqual(result, 1)
        self.assertTrue(report["status"].startswith("built;"))
        self.assertEqual(report["notification"], "failed; local report retained")

    def test_notification_has_no_logs_or_unstructured_failure_text(self):
        self.write_program("ssh", '''
import json, sys
r=json.load(sys.stdin)
assert set(r) == {'id','status','base_commit','candidate_commit','hosts','repair_attempts',
                  'inputs_refreshed','independent_pin_count','failed_stage','failure_kind','changed_inputs'}
assert 'failure' not in r and 'steps' not in r
''')
        result, _, report = self.run_preparation(notify_signal=True)
        self.assertEqual(result, 0)
        self.assertEqual(report["notification"], "submitted")

    def test_failure_diagnostics_are_structured_and_do_not_send_logs(self):
        self.write_program("nix", "import sys\nprint('Certs in blocklist but not in cert store: PRIVATE LOG')\nsys.exit(1 if 'check' in sys.argv else 0)")
        self.write_program("ssh", '''
import json, sys
r=json.load(sys.stdin)
assert r['failed_stage'] == 'flake-check'
assert r['failure_kind'] == 'missing_blocklisted_certificates'
assert 'PRIVATE LOG' not in json.dumps(r)
''')
        result, _, report = self.run_preparation(notify_signal=True)
        self.assertEqual(result, 1)
        self.assertEqual(report["notification"], "submitted")


if __name__ == "__main__":
    unittest.main()
