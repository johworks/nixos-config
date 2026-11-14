import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "nixos_lab", Path(__file__).with_name("lab.py")
)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


class SelectionTests(unittest.TestCase):
    def test_linked_worktree_uses_git_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / ".git").write_text("gitdir: /unused/main/.git/worktrees/test\n")
            self.assertEqual(lab.flake_reference(str(root)), "git+" + root.as_uri())
            nested = root / "nested flake"
            nested.mkdir()
            self.assertEqual(
                lab.flake_reference(str(nested)),
                "git+" + root.as_uri() + "?dir=nested%20flake",
            )

    def test_non_git_and_remote_references(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                lab.flake_reference(directory), "path:" + str(Path(directory).resolve())
            )
        for value in ["github:owner/repo", "path:/explicit/path", "git+file:///repo"]:
            self.assertEqual(lab.flake_reference(value), value)

    def test_state_rejects_different_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                state=directory,
                flake=".#laptop",
                hardware="hardware.nix",
                compat=None,
                user="john",
            )
            instance = lab.NixosLab(args)
            instance.check_selection()
            instance.check_selection()
            args.flake = ".#desktop"
            with self.assertRaisesRegex(RuntimeError, "different selection"):
                instance.check_selection()

    def test_nix_string_escapes_interpolation(self):
        self.assertEqual(
            lab.nix_string('x${builtins.abort "bad"}'),
            '"x\\${builtins.abort \\"bad\\"}"',
        )


class TimingTests(unittest.TestCase):
    def test_timing_is_reported_even_when_stage_fails(self):
        output = io.StringIO()
        with patch.object(lab.time, "monotonic", side_effect=[10.0, 12.5]):
            with redirect_stderr(output), self.assertRaisesRegex(ValueError, "failed"):
                with lab.timed("copy to guest"):
                    raise ValueError("failed")
        self.assertEqual(output.getvalue(), "nixos-lab timing: copy to guest: 2.50s\n")


if __name__ == "__main__":
    unittest.main()
