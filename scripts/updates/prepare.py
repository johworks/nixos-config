"""Prepare and check isolated NixOS candidates. Never activate a host."""

import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import socket
import subprocess
import sys
import time
import uuid
from urllib.parse import quote


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean_environment(home):
    """Builds do not inherit agent/API/SSH credentials or the user's HOME."""
    return {
        key: value for key, value in {
            "PATH": os.environ.get("PATH", os.defpath),
            "HOME": str(home), "LANG": "C.UTF-8", "NIX_REMOTE": "daemon",
            "SSL_CERT_FILE": os.environ.get("SSL_CERT_FILE"),
            "NIX_SSL_CERT_FILE": os.environ.get("NIX_SSL_CERT_FILE"),
        }.items() if value is not None
    }


def repair_options(candidate, codex="codex"):
    """The client retains its sign-in; generated commands cannot read it."""
    executable = Path(shutil.which(codex) or codex).resolve()
    runtime = executable.parent.parent if executable.name == "codex.js" else executable
    permissions = (
        '{extends=":workspace",filesystem={":root"="deny",":minimal"="read",'
        '":slash_tmp"="deny","/nix/store"="read",'
        + json.dumps(str(runtime)) + '="read",'
        '":workspace_roots"={"."="write"}},network={enabled=false}}'
    )
    return [
        "--ignore-user-config", "--ignore-rules", "--ephemeral", "--json",
        "-c", 'approval_policy="never"',
        "-c", 'default_permissions="update-repair"',
        "-c", "permissions.update-repair=" + permissions,
        "-c", 'web_search="disabled"',
        "-c", "shell_environment_policy.set.HOME=" + json.dumps(str(candidate / ".worker/home")),
        "-c", "shell_environment_policy.set.TMPDIR=" + json.dumps(str(candidate / ".worker/tmp")),
    ]


def pinned_sources(candidate):
    pins = []
    for name, relative in (
        ("Home Assistant", "modules/nixos/home-assistant.nix"),
        ("ESPHome", "modules/nixos/esphome.nix"),
        ("Stremio", "modules/nixos/stremio/stremio.nix"),
    ):
        path = candidate / relative
        if not path.exists():
            continue
        source = path.read_text()
        values = re.findall(r'(?:image|url|sha256)\s*=\s*"([^"\n]+)"', source)
        pins.append({"name": name, "file": relative, "values": values,
                     "status": "independent pin refresh not implemented"})
    return pins


class StepFailed(Exception):
    pass


class Preparation:
    def __init__(self, args):
        self.args = args
        self.deadline = time.monotonic() + args.timeout
        self.state = args.state_dir.expanduser().resolve()
        self.state.mkdir(parents=True, mode=0o700, exist_ok=True)
        info = self.state.stat()
        if info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("State directory must be user-owned and mode 0700")
        self.lock = open(self.state / "prepare.lock", "a")
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.lock.close()
            raise
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        self.run = self.state / (stamp + "-" + uuid.uuid4().hex[:8])
        self.run.mkdir(mode=0o700)
        self.candidate = self.run / "candidate"
        self.home = self.run / "build-home"
        self.home.mkdir(mode=0o700)
        (self.run / "roots").mkdir()
        self.env = clean_environment(self.home)
        self.report = {"id": self.run.name, "status": "preparing", "steps": [],
                       "hosts": {}, "repair_attempts": 0,
                       "inputs_refreshed": not args.no_refresh,
                       "activation": "requires separate operator approval; no executor installed"}
        self.save()

    def save(self):
        temporary = self.run / "report.json.tmp"
        temporary.write_text(json.dumps(self.report, indent=2) + "\n")
        temporary.replace(self.run / "report.json")

    def step(self, name, command, cwd=None, timeout=None, env=None, stdin=None, final_report=False):
        # Reporting has its own short allowance so a timed-out build can notify.
        seconds = timeout if final_report else min(timeout or self.args.timeout, self.deadline - time.monotonic())
        if seconds <= 0:
            raise StepFailed("Job time limit reached")
        log = self.run / f"{len(self.report['steps']):02d}-{name}.log"
        record = {"name": name, "command": command, "log": log.name}
        self.report["steps"].append(record)
        self.save()
        started = time.monotonic()
        with log.open("w") as output:
            process = subprocess.Popen(command, cwd=cwd or self.run, env=env or self.env,
                                       stdin=subprocess.PIPE if stdin else subprocess.DEVNULL,
                                       stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                process.communicate(input=stdin.encode() if stdin else None, timeout=seconds)
                record["exit_code"] = process.returncode
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                record["exit_code"] = process.returncode
                record["interrupted"] = True
                raise
            finally:
                record["seconds"] = round(time.monotonic() - started, 2)
                self.save()
        if process.returncode:
            raise StepFailed(f"{name} failed; see {log.name}")
        return log.read_text()

    def snapshot(self):
        self.step("stage", ["git", "add", "--all"], self.candidate)
        # Allow an unchanged candidate (verification runs use --no-refresh).
        staged = self.step("staged", ["git", "diff", "--cached", "--name-only"], self.candidate)
        if staged.strip():
            self.step("commit", ["git", "-c", "user.name=NixOS Update Preparation",
                                 "-c", "user.email=updates@localhost", "-c", "commit.gpgsign=false",
                                 "commit", "-m", "Prepare checked NixOS update candidate"], self.candidate)
        self.report["candidate_commit"] = self.step("revision", ["git", "rev-parse", "HEAD"], self.candidate).strip()
        self.report["lock_sha256"] = digest(self.candidate / "flake.lock")
        self.step("diff", ["git", "diff", self.report["base_commit"], "HEAD"], self.candidate)
        self.report["independent_pins"] = pinned_sources(self.candidate)
        inventory = "docs/temporary-fixes.md"
        self.report["temporary_fix_review"] = {
            "inventory": inventory,
            "status": "not reviewed; operator review required" if (self.candidate / inventory).is_file()
                      else "inventory missing; operator review required",
        }
        lock = json.loads((self.candidate / "flake.lock").read_text())
        self.report["inputs"] = {
            name: {key: node.get("locked", {}).get(key) for key in ("rev", "narHash", "lastModified")}
            for name, node in lock["nodes"].items() if "locked" in node
        }
        self.save()

    def checks(self):
        changed = self.step("changed-nix", ["git", "diff", "--name-only", self.report["base_commit"], "HEAD", "--", "*.nix"], self.candidate)
        if changed.strip():
            self.step("format", ["nixfmt", "--check", *changed.splitlines()], self.candidate)
        self.step("flake-check", ["nix", "--store", "daemon", "--max-jobs", "1", "--cores", "2",
                  "flake", "check", "--no-write-lock-file"], self.candidate)
        for host in self.args.host:
            root = self.run / "roots" / host
            self.step("build-" + host, ["nix", "--store", "daemon", "--max-jobs", "1", "--cores", "2", "build", "--no-write-lock-file",
                      "--out-link", str(root), f".#nixosConfigurations.{host}.config.system.build.toplevel"], self.candidate)
            output = str(root.resolve(strict=True))
            if not re.fullmatch(r"/nix/store/[a-z0-9]{32}-nixos-system-[^/]+", output):
                raise StepFailed("Build returned an unexpected system path")
            self.report["hosts"][host] = {"system": output, "status": "built"}
            self.save()
        if self.step("clean", ["git", "status", "--porcelain"], self.candidate).strip():
            raise StepFailed("Candidate changed during checks")
        if digest(self.candidate / "flake.lock") != self.report["lock_sha256"]:
            raise StepFailed("Lock file changed during checks")
        if self.args.vm_lab and "desktop" in self.args.host:
            self.test_desktop_vm()

    def test_desktop_vm(self):
        state = self.run / "desktop-vm"
        command = [self.args.vm_lab, "--state", str(state), "--flake", "git+file://" + quote(str(self.candidate)) + "#desktop",
                   "--hardware", "hosts/desktop/hardware-configuration.nix",
                   "--compat", str(self.candidate / "scripts/nixos-lab/desktop-compat.nix")]
        # Choose an available loopback port; the lab pins the guest SSH host key.
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        self.report["desktop_vm"] = "running"
        self.save()
        try:
            self.step("vm-start", [*command, "start", "--port", str(port)])
            self.step("vm-system", [*command, "exec", "--root", "--", "systemctl", "is-system-running", "--wait"])
            self.step("vm-reboot", [*command, "reboot"])
            self.step("vm-system-after-reboot", [*command, "exec", "--root", "--", "systemctl", "is-system-running", "--wait"])
            self.step("vm-display-manager", [*command, "exec", "--root", "--", "systemctl", "is-active", "display-manager.service"])
            self.report["desktop_vm"] = "passed"
        except BaseException:
            self.report["desktop_vm"] = "failed"
            raise
        finally:
            # QEMU runs in its own session, so always stop it even after a timeout.
            try:
                subprocess.run([*command, "stop"], cwd=self.run, env=self.env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=70, check=True)
            except (OSError, subprocess.SubprocessError):
                try:
                    subprocess.run([*command, "force-stop"], cwd=self.run, env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15, check=True)
                except (OSError, subprocess.SubprocessError):
                    pass
                self.report["desktop_vm"] = "cleanup failed"
                self.save()
                raise StepFailed("Desktop VM cleanup failed; inspect retained VM state")
            self.save()

    def repair(self, reason):
        if (self.candidate / ".codex/config.toml").exists():
            raise StepFailed("Project Codex config requires operator review before repair")
        for directory in ("home", "tmp"):
            (self.candidate / ".worker" / directory).mkdir(parents=True, exist_ok=True)
        # Copy only bounded diagnostic context into the writable candidate. The
        # original logs and report stay outside the agent's filesystem access.
        failures = [step for step in self.report["steps"] if step.get("exit_code", 0)]
        context = "\n\n".join((self.run / step["log"]).read_text(errors="replace")[-16000:] for step in failures[-3:])
        (self.candidate / ".worker/failure.txt").write_text(context)
        prompt = (
            "Repair this isolated NixOS update candidate. Failure: " + str(reason) + ". "
            "Read .worker/failure.txt and relevant source. Make the smallest justified fix. "
            "The coordinator owns Beads, Git commits, flake checks and builds; do not run bd or commit. "
            "Do not activate/reboot hosts, contact live services/databases, start other agents, weaken TLS, "
            "remove checks, alter trust/privilege policy, or bypass switch inhibitors. "
            "Commands are limited to this candidate and runtime tools; no network or host credentials. "
            "If a fix requires an operator, leave the source unchanged and explain why. "
            "Finish with the exact files changed, rationale, and unverified behavior."
        )
        self.report["repair_attempts"] += 1
        agent_env = clean_environment(Path.home())
        if os.environ.get("CODEX_HOME"):
            agent_env["CODEX_HOME"] = os.environ["CODEX_HOME"]
        self.step("repair", [self.args.codex, "exec", *repair_options(self.candidate, self.args.codex),
                            "-C", str(self.candidate), "-"], timeout=600,
                  env=agent_env, stdin=prompt)

    def notify(self):
        failed = [step for step in self.report["steps"] if step.get("exit_code", 0)]
        summary = {key: self.report.get(key) for key in (
            "id", "status", "base_commit", "candidate_commit", "hosts", "repair_attempts", "inputs_refreshed",
        )}
        summary["independent_pin_count"] = len(self.report.get("independent_pins", []))
        summary["desktop_vm"] = self.report.get("desktop_vm", "not run")
        summary["failed_stage"] = failed[-1]["name"] if failed and self.report["status"] == "failed" else None
        summary["failure_kind"] = "unknown"
        if summary["failed_stage"]:
            log = (self.run / failed[-1]["log"]).read_text(errors="replace")
            if "Certs in blocklist but not in cert store:" in log:
                summary["failure_kind"] = "missing_blocklisted_certificates"
        summary["changed_inputs"] = []
        refresh = next((step for step in self.report["steps"] if step["name"] == "refresh"), None)
        if refresh:
            log = (self.run / refresh["log"]).read_text(errors="replace")
            known = {"firefox-addons", "home-manager", "home-managerStable", "nixpkgsOpencode",
                     "nixpkgsStable", "nixpkgsUnstable", "nixpkgsVaultwarden", "rust-overlay", "sops-nix"}
            summary["changed_inputs"] = sorted(set(re.findall(r"Updated input '([^']+)'", log)) & known)
        try:
            self.step("notify", ["ssh", "-F", "/dev/null", "-i", str(self.args.signal_key.expanduser()),
                      "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "john@192.168.10.1",
                      "sudo -n -u signal-updates /run/current-system/sw/bin/signal-updates report"],
                      env=clean_environment(Path.home()), stdin=json.dumps(summary), timeout=40, final_report=True)
            self.report["notification"] = "submitted"
        except (StepFailed, OSError, subprocess.TimeoutExpired):
            self.report["notification"] = "failed; local report retained"

    def execute(self):
        try:
            base = self.step("base", ["git", "-C", str(self.args.repo.resolve()), "rev-parse", "--verify", self.args.base + "^{commit}"]).strip()
            self.report["base_commit"] = base
            self.step("clone", ["git", "clone", "--no-hardlinks", "--no-checkout", "--", str(self.args.repo.resolve()), str(self.candidate)])
            self.step("checkout", ["git", "checkout", "--detach", base], self.candidate)
            with (self.candidate / ".git/info/exclude").open("a") as exclude:
                exclude.write("\n/.worker/\n")
            if not self.args.no_refresh:
                self.step("refresh", ["nix", "--store", "daemon", "flake", "update"], self.candidate)
            for attempt in range(self.args.repair_attempts + 1):
                self.report["hosts"] = {}
                self.snapshot()
                try:
                    self.checks()
                    break
                except StepFailed as error:
                    if attempt == self.args.repair_attempts or self.report.get("desktop_vm") in ("failed", "cleanup failed"):
                        raise
                    self.repair(error)
            self.report["status"] = "built; operator review required"
        except (StepFailed, OSError, ValueError, subprocess.TimeoutExpired) as error:
            self.report["status"] = "failed"
            self.report["failure"] = str(error)
        except BaseException:
            self.report["status"] = "interrupted"
            raise
        finally:
            self.save()
            if self.args.notify_signal and self.report["status"] != "interrupted":
                self.notify()
                self.save()
            self.lock.close()
        print(self.run / "report.json")
        return 0 if self.report["status"].startswith("built;") and self.report.get("notification") != "failed; local report retained" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--base", default="main")
    parser.add_argument("--state-dir", type=Path, default=Path.home() / ".local/state/nixos-updates")
    parser.add_argument("--host", choices=["desktop", "nuc"], action="append")
    parser.add_argument("--no-refresh", action="store_true", help="Verify the base without updating inputs")
    parser.add_argument("--repair-attempts", type=int, choices=range(3), default=2)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--notify-signal", action="store_true")
    parser.add_argument("--vm-lab", help="Path to nixos-lab for a disposable desktop boot test")
    parser.add_argument("--signal-key", type=Path, default=Path.home() / ".ssh/id_ed25519_nuc")
    parser.add_argument("--timeout", type=int, default=3600, help="Whole job limit in seconds")
    args = parser.parse_args()
    args.host = args.host or ["desktop", "nuc"]
    if args.timeout <= 0 or args.base.startswith("-"):
        parser.error("Use a positive timeout and a Git revision without a leading dash")
    if os.geteuid() == 0:
        parser.error("Run preparation as your normal user, without sudo")
    def interrupt(_signal, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupt)
    try:
        return Preparation(args).execute()
    except KeyboardInterrupt:
        return 130
    except (OSError, ValueError) as error:
        print("Could not start preparation: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
