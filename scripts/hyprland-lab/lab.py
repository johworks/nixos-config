"""A disposable Hyprland guest, controlled from the host without host sudo."""

import argparse
import fcntl
import json
import os
import shlex
import socket
import subprocess
import sys
import time
from pathlib import Path


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, **kwargs)


class Lab:
    def __init__(self, args):
        self.args = args
        self.state = Path(args.state).expanduser().resolve()
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.state.stat().st_uid != os.getuid() or self.state.stat().st_mode & 0o077:
            raise RuntimeError(
                "State directory must be owned by you and have mode 0700"
            )
        self.current = self.state / "current"

    def info(self):
        return json.loads((self.current / "run.json").read_text())

    def ssh_options(self):
        return [
            "-F",
            "/dev/null",
            "-i",
            str(self.current / "client_key"),
            "-p",
            str(self.info()["port"]),
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "BatchMode=yes",
            "-o",
            "ForwardAgent=no",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            "HostKeyAlias=hyprland-lab",
            "-o",
            f"UserKnownHostsFile={self.current / 'known_hosts'}",
            "-o",
            "ConnectTimeout=3",
            "-o",
            "LogLevel=ERROR",
        ]

    def ssh(self, argv, *, root=False, capture=False, **kwargs):
        if root:
            argv = ["sudo", "-n", *argv]
        return run(
            ["ssh", *self.ssh_options(), "john@127.0.0.1", shlex.join(argv)],
            stdout=subprocess.PIPE if capture else None,
            **kwargs,
        )

    def session(self, argv, **kwargs):
        # SSH logins do not inherit the running graphical session's environment.
        script = """
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["instance"])')
export WAYLAND_DISPLAY=$(hyprctl instances -j | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["wl_socket"])')
exec "$@"
"""
        return self.ssh(["bash", "-c", script, "hyprlab-session", *argv], **kwargs)

    def qmp(self, command, arguments=None):
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(10)
            sock.connect(str(self.current / "qmp.sock"))
            with sock.makefile("rwb", buffering=0) as stream:
                json.loads(stream.readline())
                for index, (name, params) in enumerate(
                    [("qmp_capabilities", {}), (command, arguments or {})]
                ):
                    stream.write(
                        json.dumps(
                            {"execute": name, "arguments": params, "id": index}
                        ).encode()
                        + b"\n"
                    )
                    while True:
                        message = json.loads(stream.readline())
                        if message.get("id") == index:
                            if "error" in message:
                                raise RuntimeError(message["error"])
                            break
                return message["return"]

    def running(self):
        try:
            return self.qmp("query-status")["status"] != "shutdown"
        except (OSError, ValueError):
            return False

    def build(self, target="vm"):
        output = self.state / ("base" if target == "vm" else "candidate")
        run(
            [
                "nix",
                "--store",
                "daemon",
                "build",
                "--no-write-lock-file",
                f"{self.args.flake}#nixosConfigurations.hyprland-lab.config.system.build.{target}",
                "--out-link",
                str(output),
            ]
        )
        return output

    def start(self):
        if self.running():
            self.wait_ready()
            return
        if not os.access("/dev/kvm", os.R_OK | os.W_OK):
            raise RuntimeError(
                "KVM is unavailable here; launch outside the device-hiding agent sandbox"
            )
        if not (self.state / "base").exists():
            self.build()
        if not self.current.exists():
            directory = self.state / "runs" / time.strftime("%Y%m%d-%H%M%S")
            directory.mkdir(parents=True, mode=0o700)
            self.current.symlink_to(directory)
            for name in ["client_key", "host_key"]:
                run(
                    [
                        "ssh-keygen",
                        "-q",
                        "-t",
                        "ed25519",
                        "-N",
                        "",
                        "-f",
                        str(directory / name),
                    ]
                )
            (directory / "known_hosts").write_text(
                "hyprland-lab " + (directory / "host_key.pub").read_text()
            )
            # Retain the exact launcher/base image even after subsequent builds.
            run(
                [
                    "nix-store",
                    "--add-root",
                    str(directory / "base"),
                    "--indirect",
                    "--realise",
                    str((self.state / "base").resolve()),
                ],
                stdout=subprocess.DEVNULL,
            )
            (directory / "run.json").write_text(json.dumps({"port": self.args.port}))
        directory = self.current.resolve()
        for name in ["qmp.sock", "qemu.pid"]:
            (directory / name).unlink(missing_ok=True)
        env = os.environ.copy()
        for name in [
            "QEMU_OPTS",
            "QEMU_KERNEL_PARAMS",
            "QEMU_NET_OPTS",
            "NIX_DISK_IMAGE",
            "NIX_EFI_VARS",
        ]:
            env.pop(name, None)
        env.update(
            {
                "NIX_DISK_IMAGE": str(directory / "disk.qcow2"),
                "NIX_EFI_VARS": str(directory / "efi-vars.fd"),
                "QEMU_NET_OPTS": f"hostfwd=tcp:127.0.0.1:{self.info()['port']}-:22",
            }
        )
        (launcher,) = (directory / "base" / "bin").glob("run-*-vm")
        display = (
            "gtk,gl=on"
            if self.args.window
            else f"egl-headless,rendernode={self.args.rendernode}"
        )
        with (directory / "qemu.log").open("ab") as log:
            process = subprocess.Popen(
                [
                    str(launcher),
                    "-display",
                    display,
                    "-qmp",
                    f"unix:{directory / 'qmp.sock'},server=on,wait=off",
                    "-pidfile",
                    str(directory / "qemu.pid"),
                    "-serial",
                    f"file:{directory / 'serial.log'}",
                    "-monitor",
                    "none",
                    "-fw_cfg",
                    f"name=opt/hyprlab.authorized-key,file={directory / 'client_key.pub'}",
                    "-fw_cfg",
                    f"name=opt/hyprlab.host-key,file={directory / 'host_key'}",
                ],
                cwd=directory,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )
        self.wait_ready(process)

    def wait_ready(self, process=None):
        directory = self.current.resolve()
        for _ in range(180):
            if process is not None and process.poll() is not None:
                raise RuntimeError(f"QEMU exited; see {directory / 'qemu.log'}")
            try:
                result = self.session(
                    ["hyprctl", "monitors", "-j"],
                    capture=True,
                    stderr=subprocess.DEVNULL,
                )
                if json.loads(result.stdout):
                    print(f"Ready: {directory}")
                    return
            except (subprocess.CalledProcessError, ValueError):
                pass
            time.sleep(1)
        raise RuntimeError(
            f"Guest graphical session did not become ready; see {directory / 'serial.log'}"
        )

    def reboot(self):
        before = self.ssh(
            ["cat", "/proc/sys/kernel/random/boot_id"], capture=True
        ).stdout
        self.ssh(["systemctl", "--no-block", "reboot"], root=True)
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

    def stop(self):
        if not self.running():
            return
        self.qmp("system_powerdown")
        for _ in range(60):
            if not self.running():
                return
            time.sleep(1)
        raise RuntimeError(
            "Guest has not stopped; inspect logs before using force-stop"
        )

    def reset(self):
        self.stop()
        # Preserve old evidence and disks; only a new run loses experimental state.
        self.current.unlink(missing_ok=True)
        print("Next start will create a fresh run; previous artifacts are retained")

    def screenshot(self, path):
        target = Path(path).expanduser().resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        result = self.session(["grim", "-"], capture=True)
        if not result.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Guest did not return a PNG screenshot")
        target.write_bytes(result.stdout)
        print(target)

    def key(self, combination):
        self.qmp(
            "send-key",
            {
                "keys": [
                    {"type": "qcode", "data": key} for key in combination.split("-")
                ],
                "hold-time": 100,
            },
        )

    def click(self, x, y, button):
        monitors = json.loads(
            self.session(["hyprctl", "monitors", "-j"], capture=True).stdout
        )
        (monitor,) = monitors
        width, height = monitor["width"], monitor["height"]
        if not 0 <= x < width or not 0 <= y < height:
            raise RuntimeError(f"Coordinates must be inside {width}x{height}")
        self.qmp(
            "input-send-event",
            {
                "events": [
                    {
                        "type": "abs",
                        "data": {"axis": "x", "value": round(x * 32767 / (width - 1))},
                    },
                    {
                        "type": "abs",
                        "data": {"axis": "y", "value": round(y * 32767 / (height - 1))},
                    },
                ]
            },
        )
        for down in [True, False]:
            self.qmp(
                "input-send-event",
                {"events": [{"type": "btn", "data": {"down": down, "button": button}}]},
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
                "ssh-ng://john@127.0.0.1",
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

    def verify(self):
        """Exercise the real guest UI and retain evidence, including on failure."""
        artifacts = (
            self.current.resolve() / "artifacts" / time.strftime("%Y%m%d-%H%M%S")
        )
        artifacts.mkdir(parents=True)
        report = {"checks": [], "artifacts": str(artifacts)}

        def check(name, condition):
            if not condition:
                raise RuntimeError(f"Verification failed: {name}")
            report["checks"].append(name)

        def data(*argv):
            return json.loads(self.session(list(argv), capture=True).stdout)

        def wait_for(name, predicate):
            for _ in range(60):
                try:
                    if predicate():
                        check(name, True)
                        return
                except subprocess.CalledProcessError:
                    pass
                time.sleep(0.5)
            check(name, False)

        def terminals():
            return [
                c
                for c in data("hyprctl", "clients", "-j")
                if c["class"].lower() == "kitty" and c["workspace"]["id"] == 9
            ]

        old_workspace = None
        existing = set()
        try:
            report["kvm"] = self.qmp("query-kvm")
            check("hardware virtualization enabled", report["kvm"]["enabled"])
            check(
                "guest root",
                self.ssh(["id", "-u"], root=True, capture=True).stdout.strip() == b"0",
            )
            check(
                "no Hyprland config errors",
                not self.session(
                    ["hyprctl", "configerrors"], capture=True
                ).stdout.strip(),
            )
            report["monitors"] = data("hyprctl", "monitors", "-j")
            report["systeminfo"] = self.session(
                ["hyprctl", "systeminfo"], capture=True
            ).stdout.decode()
            report["generation"] = (
                self.ssh(["readlink", "-f", "/run/current-system"], capture=True)
                .stdout.decode()
                .strip()
            )
            self.session(
                [
                    "systemctl",
                    "--user",
                    "is-active",
                    "waybar.service",
                    "xdg-desktop-portal-hyprland.service",
                ],
                capture=True,
            )
            check("Waybar and Hyprland portal active", True)
            mounts = (
                self.ssh(["findmnt", "-rn", "-o", "FSTYPE"], capture=True)
                .stdout.decode()
                .splitlines()
            )
            check("no host filesystem shares", not set(mounts) & {"virtiofs", "9p"})
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                listener.listen()
                network_probe = """
import socket,sys
for host, port in [("10.0.2.2", int(sys.argv[1])), ("192.168.10.1", 22), ("1.1.1.1", 443)]:
    try:
        with socket.create_connection((host, port), timeout=2):
            raise SystemExit("Unexpected guest egress to " + host)
    except OSError:
        pass
"""
                self.ssh(
                    ["python3", "-c", network_probe, str(listener.getsockname()[1])],
                    capture=True,
                )
            check("guest egress blocked to host listener, LAN and Internet", True)
            old_workspace = data("hyprctl", "activeworkspace", "-j")["id"]
            existing = {c["address"] for c in data("hyprctl", "clients", "-j")}
            self.key("meta_l-9")
            wait_for(
                "workspace keyboard binding",
                lambda: data("hyprctl", "activeworkspace", "-j")["id"] == 9,
            )
            time.sleep(1)
            self.screenshot(artifacts / "01-desktop.png")
            count = len(terminals())
            self.key("meta_l-q")
            wait_for("terminal keyboard binding", lambda: len(terminals()) > count)
            self.click(800, 450, "left")
            proof = f"HYPRLAB_INPUT_OK_{time.time_ns()}"
            self.session(
                [
                    "wtype",
                    "--",
                    f"printf '%s\\n' {proof} | tee /tmp/hyprlab-input-proof",
                ]
            )
            self.key("ret")
            wait_for(
                "mouse focus and typed terminal command",
                lambda: (
                    self.ssh(
                        ["cat", "/tmp/hyprlab-input-proof"],
                        capture=True,
                        stderr=subprocess.DEVNULL,
                    ).stdout.strip()
                    == proof.encode()
                ),
            )
            self.screenshot(artifacts / "02-terminal.png")
            self.key("meta_l-r")
            wait_for(
                "application launcher binding",
                lambda: (
                    b"wofi"
                    in self.session(["hyprctl", "layers", "-j"], capture=True).stdout
                ),
            )
            self.session(["wtype", "--", "kitty"])
            self.screenshot(artifacts / "03-launcher.png")
            count = len(terminals())
            self.key("ret")
            wait_for("application launcher selection", lambda: len(terminals()) > count)
            time.sleep(1)
            self.screenshot(artifacts / "04-tiling.png")
            sizes = sorted(c["size"] for c in terminals())
            self.key("meta_l-j")
            wait_for(
                "split orientation keyboard binding",
                lambda: sorted(c["size"] for c in terminals()) != sizes,
            )
            time.sleep(1)
            self.screenshot(artifacts / "04b-split.png")
            self.key("meta_l-j")
            original_border = data("hyprctl", "getoption", "general:border_size", "-j")[
                "int"
            ]
            temporary_border = 10 if original_border != 10 else 2
            report["visualExperiment"] = {
                "option": "general:border_size",
                "original": original_border,
                "temporary": temporary_border,
            }
            self.session(
                ["hyprctl", "keyword", "general:border_size", str(temporary_border)],
                capture=True,
            )
            check(
                "live visual change applied",
                data("hyprctl", "getoption", "general:border_size", "-j")["int"]
                == temporary_border,
            )
            time.sleep(1)
            self.screenshot(artifacts / "05-thick-borders.png")
            self.session(["hyprctl", "reload"], capture=True)
            check(
                "visual change restored",
                data("hyprctl", "getoption", "general:border_size", "-j")["int"]
                == original_border,
            )
            check(
                "no config errors after reload",
                not self.session(
                    ["hyprctl", "configerrors"], capture=True
                ).stdout.strip(),
            )
            time.sleep(1)
            self.screenshot(artifacts / "06-restored.png")
            self.key("meta_l-e")
            wait_for(
                "file manager keyboard binding",
                lambda: any(
                    "nautilus" in c["class"].lower()
                    for c in data("hyprctl", "clients", "-j")
                ),
            )
            self.session(
                [
                    "notify-send",
                    "--expire-time=8000",
                    "Hyprland lab",
                    "Native applications and notifications",
                ]
            )
            time.sleep(1)
            self.screenshot(artifacts / "07-native-apps.png")
            report["passed"] = True
        except Exception as error:
            report.update({"passed": False, "error": str(error)})
            try:
                self.screenshot(artifacts / "failure.png")
            except (
                RuntimeError,
                OSError,
                subprocess.CalledProcessError,
                ValueError,
            ) as capture_error:
                print(
                    f"Could not capture failure screenshot: {capture_error}",
                    file=sys.stderr,
                )
            raise
        finally:
            (artifacts / "report.json").write_text(json.dumps(report, indent=2) + "\n")
            if old_workspace is not None:
                self.session(["hyprctl", "reload"], capture=True)
                for client in data("hyprctl", "clients", "-j"):
                    if client["address"] not in existing:
                        self.session(
                            [
                                "hyprctl",
                                "dispatch",
                                "closewindow",
                                "address:" + client["address"],
                            ],
                            capture=True,
                        )
                self.session(
                    ["hyprctl", "dispatch", "workspace", str(old_workspace)],
                    capture=True,
                )
        print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--state",
        default=os.environ.get("HYPRLAB_STATE", "~/.local/state/hyprland-lab"),
    )
    parser.add_argument("--flake", default=".", help="Source flake to build/deploy")
    sub = parser.add_subparsers(dest="command", required=True)
    for command in [
        "build",
        "stop",
        "reset",
        "status",
        "force-stop",
        "deploy",
        "verify",
        "wait",
        "reboot",
    ]:
        sub.add_parser(command)
    start = sub.add_parser("start")
    start.add_argument(
        "--window",
        action="store_true",
        help="Show a local GTK window instead of rendering headlessly",
    )
    start.add_argument("--port", type=int, default=2222)
    start.add_argument("--rendernode", default="/dev/dri/renderD128")
    execute = sub.add_parser("exec")
    execute.add_argument("--root", action="store_true")
    execute.add_argument("argv", nargs=argparse.REMAINDER)
    session = sub.add_parser("session")
    session.add_argument("argv", nargs=argparse.REMAINDER)
    sub.add_parser("ssh")
    shot = sub.add_parser("shot")
    shot.add_argument("path")
    key = sub.add_parser("key")
    key.add_argument("combination", help="QEMU qcodes, e.g. meta_l-q, esc, ctrl-c")
    typing = sub.add_parser("type")
    typing.add_argument("text")
    click = sub.add_parser("click")
    click.add_argument("x", type=int)
    click.add_argument("y", type=int)
    click.add_argument("--button", choices=["left", "middle", "right"], default="left")
    args = parser.parse_args()
    lab = Lab(args)
    # Serialize lifecycle mutations so concurrent agents cannot reset each other.
    with (lab.state / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        match args.command:
            case "build":
                lab.build()
            case "start":
                lab.start()
            case "stop":
                lab.stop()
            case "force-stop":
                lab.qmp("quit")
            case "reset":
                lab.reset()
            case "status":
                print(
                    json.dumps(
                        {"running": lab.running(), "run": str(lab.current.resolve())},
                        indent=2,
                    )
                )
            case "exec":
                argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
                if not argv:
                    parser.error("exec requires a guest command")
                lab.ssh(argv, root=args.root)
            case "session":
                argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
                if not argv:
                    parser.error("session requires a guest command")
                lab.session(argv)
            case "ssh":
                run(["ssh", *lab.ssh_options(), "-t", "john@127.0.0.1"])
            case "shot":
                lab.screenshot(args.path)
            case "key":
                lab.key(args.combination)
            case "type":
                lab.session(["wtype", "--", args.text])
            case "click":
                lab.click(args.x, args.y, args.button)
            case "deploy":
                lab.deploy()
            case "verify":
                lab.verify()
            case "wait":
                lab.wait_ready()
            case "reboot":
                lab.reboot()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"hyprlab: {error}", file=sys.stderr)
        sys.exit(1)
