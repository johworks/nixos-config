import importlib.util
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

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


if __name__ == "__main__":
    unittest.main()
