"""Run a selected NixOS flake configuration in an isolated QEMU lab."""

import argparse
import fcntl
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "hyprland-lab"))
from lab import Lab, run


def nix_string(value):
    return json.dumps(value).replace("${", "\\${")


class NixosLab(Lab):
    def check_selection(self):
        flake, separator, host = self.args.flake.rpartition("#")
        if not separator or not flake or not host:
            raise RuntimeError("--flake must select a configuration, e.g. .#desktop")
        if flake.startswith(".") or flake.startswith("/"):
            flake = str(Path(flake).resolve())
        selection = {
            "flake": flake + "#" + host,
            "hardware": self.args.hardware,
            "compat": str(Path(self.args.compat).resolve())
            if self.args.compat
            else None,
            "user": self.args.user,
        }
        record = self.state / "selection.json"
        if record.exists() and json.loads(record.read_text()) != selection:
            raise RuntimeError(
                "This state directory belongs to a different selection; use a separate --state"
            )
        if not record.exists():
            record.write_text(json.dumps(selection, indent=2))

    def build(self, target="vm"):
        flake, separator, host = self.args.flake.rpartition("#")
        if not separator or not flake or not host:
            raise RuntimeError("--flake must select a configuration, e.g. .#desktop")
        if flake.startswith(".") or flake.startswith("/"):
            flake = str(Path(flake).resolve())
        guest = Path(__file__).resolve().parent / "guest.nix"
        compat = self.args.compat
        hardware = self.args.hardware
        # Paths and attribute names are Nix string literals, not shell fragments.
        expr = """let
          flake = builtins.getFlake FLAKE;
          host = builtins.getAttr HOST flake.nixosConfigurations;
          guest = import GUEST;
          system = host.extendModules { modules = [ guest
            ({ lib, ... }: {
              disabledModules = DISABLED;
              services.displayManager.autoLogin = { enable = true; user = USER; };
              users.users.USERATTR.initialPassword = "lab";
              users.users.USERATTR.extraGroups = [ "wheel" ];
              nix.settings.trusted-users = [ USER ];
              services.openssh.settings.AllowUsers = [ USER ];
            })
          ] ++ COMPAT; };
        in system.config.system.build.TARGET"""
        replacements = {
            "FLAKE": nix_string(flake),
            "HOST": nix_string(host),
            "GUEST": nix_string(str(guest)),
            "DISABLED": "[ (flake.outPath + " + nix_string("/" + hardware) + ") ]"
            if hardware
            else "[ ]",
            "USERATTR": nix_string(self.args.user),
            "USER": nix_string(self.args.user),
            "COMPAT": "[ (import " + nix_string(str(Path(compat).resolve())) + ") ]"
            if compat
            else "[ ]",
            "TARGET": target,
        }
        expr = re.sub(
            r"FLAKE|HOST|GUEST|DISABLED|USERATTR|USER|COMPAT|TARGET",
            lambda match: replacements[match.group()],
            expr,
        )
        output = self.state / ("base" if target == "vm" else "candidate")
        run(
            [
                "nix",
                "--store",
                "daemon",
                "build",
                "--impure",
                "--expr",
                expr,
                "--out-link",
                str(output),
            ]
        )
        return output

    def ssh(self, argv, *, root=False, capture=False, **kwargs):
        if root:
            argv = ["sudo", "-n", *argv]
        return run(
            [
                "ssh",
                *self.ssh_options(),
                f"{self.args.user}@127.0.0.1",
                shlex.join(argv),
            ],
            stdout=subprocess.PIPE if capture else None,
            **kwargs,
        )

    def deploy(self):
        candidate = self.build("toplevel").resolve()
        env = os.environ.copy()
        env["NIX_SSHOPTS"] = shlex.join(self.ssh_options())
        run(
            [
                "nix",
                "--store",
                "daemon",
                "copy",
                "--no-check-sigs",
                "--to",
                f"ssh-ng://{self.args.user}@127.0.0.1",
                str(candidate),
            ],
            env=env,
        )
        self.ssh(
            [
                "nix-env",
                "--profile",
                "/nix/var/nix/profiles/system",
                "--set",
                str(candidate),
            ],
            root=True,
        )
        self.ssh([str(candidate / "bin/switch-to-configuration"), "switch"], root=True)

    def wait_ready(self, process=None):
        directory = self.current.resolve()
        for _ in range(180):
            if process is not None and process.poll() is not None:
                raise RuntimeError(f"QEMU exited; see {directory / 'qemu.log'}")
            try:
                self.ssh(["true"], capture=True, stderr=subprocess.DEVNULL)
                print(f"Ready: {directory}")
                return
            except subprocess.CalledProcessError:
                time.sleep(1)
        raise RuntimeError(
            f"Guest SSH did not become ready; see {directory / 'serial.log'}"
        )

    def reboot(self):
        before = self.ssh(
            ["cat", "/proc/sys/kernel/random/boot_id"], capture=True
        ).stdout
        try:
            self.ssh(["systemctl", "--no-block", "reboot"], root=True)
        except subprocess.CalledProcessError as error:
            if error.returncode != 255:
                raise
        for _ in range(180):
            try:
                after = self.ssh(
                    ["cat", "/proc/sys/kernel/random/boot_id"],
                    capture=True,
                    stderr=subprocess.DEVNULL,
                ).stdout
                if after != before:
                    self.wait_ready()
                    return
            except subprocess.CalledProcessError:
                pass
            time.sleep(1)
        raise RuntimeError("Guest did not complete a reboot")

    def screenshot(self, path):
        # Hyprland supports grim; Plasma uses Spectacle's portal integration.
        script = """export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
export WAYLAND_DISPLAY=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -regextype posix-extended -type s -regex '.*/wayland-[0-9]+' -printf '%f\\n' | head -1)
if command -v hyprctl >/dev/null && hyprctl instances -j | grep -q instance; then
  grim -
else
  tmp=$(mktemp --suffix=.png)
  spectacle -b -n -f -o "$tmp" >&2 && cat "$tmp"
  rm -f "$tmp"
fi"""
        result = self.ssh(["bash", "-c", script], capture=True)
        if not result.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Guest did not return a PNG screenshot")
        target = Path(path).expanduser().resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(result.stdout)
        print(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", default="~/.local/state/nixos-lab")
    parser.add_argument(
        "--flake", required=True, help="Flake and NixOS configuration, e.g. .#desktop"
    )
    parser.add_argument(
        "--hardware",
        help="Path within flake to the physical hardware module to disable",
    )
    parser.add_argument(
        "--compat", help="Optional additional guest compatibility module"
    )
    parser.add_argument("--user", default="john", help="Existing guest user")
    sub = parser.add_subparsers(dest="command", required=True)
    for command in [
        "build",
        "deploy",
        "status",
        "stop",
        "reset",
        "force-stop",
        "wait",
        "reboot",
    ]:
        sub.add_parser(command)
    start = sub.add_parser("start")
    start.add_argument("--window", action="store_true")
    start.add_argument("--port", type=int, default=2222)
    start.add_argument("--rendernode", default="/dev/dri/renderD128")
    execute = sub.add_parser("exec")
    execute.add_argument("--root", action="store_true")
    execute.add_argument("argv", nargs=argparse.REMAINDER)
    shot = sub.add_parser("shot")
    shot.add_argument("path")
    key = sub.add_parser("key")
    key.add_argument("combination")
    args = parser.parse_args()
    lab = NixosLab(args)
    with (lab.state / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        lab.check_selection()
        if args.command == "build":
            lab.build()
        elif args.command == "deploy":
            lab.deploy()
        elif args.command == "start":
            lab.start()
        elif args.command == "status":
            print(
                json.dumps(
                    {"running": lab.running(), "run": str(lab.current.resolve())},
                    indent=2,
                )
            )
        elif args.command == "stop":
            lab.stop()
        elif args.command == "reset":
            lab.reset()
        elif args.command == "force-stop":
            lab.qmp("quit")
        elif args.command == "wait":
            lab.wait_ready()
        elif args.command == "reboot":
            lab.reboot()
        elif args.command == "shot":
            lab.screenshot(args.path)
        elif args.command == "key":
            lab.key(args.combination)
        elif args.command == "exec":
            argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
            if not argv:
                parser.error("exec requires a command")
            lab.ssh(argv, root=args.root)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"nixos-lab: {error}", file=sys.stderr)
        sys.exit(1)
