"""Install Nix permissions while preserving Codex's writable user settings."""

import os
from pathlib import Path
import sys
import tempfile

import tomlkit


def back_up(path, content):
    if not path.exists():
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as output:
            output.write(content)


home = Path(sys.argv[1])
defaults = tomlkit.parse(Path(sys.argv[2]).read_text())
codex = home / ".codex"
codex.mkdir(parents=True, exist_ok=True)
config = codex / "config.toml"
original = config.read_text() if config.exists() else ""
document = tomlkit.parse(original)

# Legacy sandbox settings override named permission profiles.
document.pop("sandbox_mode", None)
document.pop("sandbox_workspace_write", None)
document["default_permissions"] = defaults["default_permissions"]
document["approval_policy"] = defaults["approval_policy"]
environment = document.setdefault("shell_environment_policy", tomlkit.table())
environment.setdefault("set", tomlkit.table())["NIX_REMOTE"] = "daemon"
if "permissions" not in document:
    document["permissions"] = tomlkit.table()
document["permissions"]["nix-workspace"] = defaults["permissions"]["nix-workspace"]
updated = tomlkit.dumps(document)

if updated != original or config.is_symlink():
    backup = codex / "config.toml.before-nix-permissions"
    if original:
        back_up(backup, original)
    # Replace a legacy store symlink without writing through it into the store.
    with tempfile.NamedTemporaryFile(mode="w", dir=codex, delete=False) as output:
        output.write(updated)
        temporary = Path(output.name)
    os.replace(temporary, config)

# Migrate only the former Home Manager symlink, preserving learned user rules.
rules = codex / "rules" / "default.rules"
if rules.is_symlink():
    target = rules.readlink()
    if target.is_relative_to("/nix/store") and str(target).endswith(
        "/.codex/rules/default.rules"
    ):
        backup = codex / "default.rules.before-nix-permissions"
        back_up(backup, rules.read_text())
        rules.unlink()

(home / ".cache" / "nix").mkdir(parents=True, exist_ok=True)
