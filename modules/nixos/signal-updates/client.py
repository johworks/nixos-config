"""Link the private transport and send one inert Note to Self delivery test."""

import argparse
import json
import re
import socket
import subprocess
import sys
import time
import uuid


SOCKET = "/run/signal-updates/rpc.sock"
TEST_MESSAGE = (
    "NUC update notifications: delivery test. "
    "No update or activation is requested."
)


class TransportError(Exception):
    pass


class Client:
    def __init__(self, path=SOCKET):
        self.path = path

    def call(self, method, params=None, timeout=30):
        request_id = str(uuid.uuid4())
        request = {"jsonrpc": "2.0", "id": request_id, "method": method}
        if params is not None:
            request["params"] = params
        deadline = time.monotonic() + timeout
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(timeout)
            connection.connect(self.path)
            connection.sendall((json.dumps(request) + "\n").encode())
            with connection.makefile("rb") as stream:
                while True:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise TransportError("Signal request timed out; check status before retrying.")
                    connection.settimeout(remaining)
                    line = stream.readline(1024 * 1024 + 1)
                    if not line or len(line) > 1024 * 1024:
                        raise TransportError("Invalid or closed Signal response.")
                    response = json.loads(line)
                    if not isinstance(response, dict):
                        raise TransportError("Invalid Signal response.")
                    # Never display personal message events or unrelated responses.
                    if response.get("id") != request_id:
                        continue
                    if "error" in response:
                        raise TransportError("Signal rejected the request; inspect service status locally.")
                    if "result" not in response:
                        raise TransportError("Signal response has no result.")
                    return response["result"]

    def accounts(self):
        accounts = self.call("listAccounts")
        if not isinstance(accounts, list):
            raise TransportError("Invalid account list.")
        return accounts

    def account(self):
        accounts = self.accounts()
        if len(accounts) != 1:
            raise TransportError("Exactly one linked account is required; run status or link.")
        account = accounts[0]
        if not isinstance(account, dict) or not isinstance(account.get("aci"), str) or not account["aci"]:
            raise TransportError("Linked account has no valid account ID.")
        return account["aci"]

    def send(self, message):
        result = self.call("send", {
            "account": self.account(),
            "noteToSelf": True,
            "notifySelf": True,
            "message": message,
        })
        if not isinstance(result, dict) or type(result.get("timestamp")) is not int:
            raise TransportError("Delivery was not confirmed; check Note to Self before retrying.")
        deliveries = result.get("results")
        if not isinstance(deliveries, list) or not deliveries or any(
            not isinstance(delivery, dict) or delivery.get("type") != "SUCCESS"
            for delivery in deliveries
        ):
            raise TransportError("Signal reported a delivery failure; check Note to Self before retrying.")

    def test(self):
        self.send(TEST_MESSAGE)


def format_report(report):
    """Only bounded build metadata is allowed into the self-chat, never logs."""
    fields = {
        "id", "status", "base_commit", "candidate_commit", "hosts", "repair_attempts",
        "inputs_refreshed", "independent_pin_count", "failed_stage",
    }
    if not isinstance(report, dict) or set(report) not in (fields, fields | {"failure_kind", "changed_inputs"}):
        raise TransportError("Invalid report fields.")
    kinds = {"unknown", "missing_blocklisted_certificates"}
    inputs = {"firefox-addons", "home-manager", "home-managerStable", "nixpkgsOpencode",
              "nixpkgsStable", "nixpkgsUnstable", "nixpkgsVaultwarden", "rust-overlay", "sops-nix"}
    kind = report.get("failure_kind", "unknown")
    changed = report.get("changed_inputs", [])
    if not isinstance(kind, str) or kind not in kinds or not isinstance(changed, list) or any(
        not isinstance(item, str) or item not in inputs for item in changed
    ) or len(changed) > len(inputs) or len(set(changed)) != len(changed):
        raise TransportError("Invalid diagnostic metadata.")
    if report["status"] not in ("built; operator review required", "failed", "interrupted"):
        raise TransportError("Invalid report status.")
    if not isinstance(report["id"], str) or not re.fullmatch(r"\d{8}T\d{6}Z-[a-f0-9]{8}", report["id"]):
        raise TransportError("Invalid report ID.")
    for field in ("base_commit", "candidate_commit"):
        value = report[field]
        if value is not None and (not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{40}", value)):
            raise TransportError("Invalid report revision.")
    for field, maximum in (("repair_attempts", 2), ("independent_pin_count", 10)):
        if type(report[field]) is not int or not 0 <= report[field] <= maximum:
            raise TransportError("Invalid report count.")
    if type(report["inputs_refreshed"]) is not bool:
        raise TransportError("Invalid refresh status.")
    hosts = report["hosts"]
    if not isinstance(hosts, dict) or set(hosts) - {"desktop", "nuc"}:
        raise TransportError("Invalid report hosts.")
    titles = {"failed": "failed", "interrupted": "interrupted", "built; operator review required": "builds ready for review"}
    lines = ["NixOS update preparation: " + titles[report["status"]]]
    lines.append("Attempted to refresh flake dependencies in a separate candidate." if report["inputs_refreshed"]
                 else "Checked a separate candidate without refreshing dependencies.")
    if changed:
        lines.append("Updated inputs: " + ", ".join(changed) + ".")
    for name, host in sorted(hosts.items()):
        if not isinstance(host, dict) or set(host) != {"system", "status"} or host["status"] != "built":
            raise TransportError("Invalid host build result.")
        if not isinstance(host["system"], str) or not re.fullmatch(r"/nix/store/[a-z0-9]{32}-nixos-system-[A-Za-z0-9.+_-]+", host["system"]):
            raise TransportError("Invalid system output.")
        lines.append(name + ": " + host["system"])
    stage = report["failed_stage"]
    if stage is not None:
        if not isinstance(stage, str) or stage not in {"base", "clone", "checkout", "refresh", "stage", "staged", "commit", "revision",
                         "diff", "changed-nix", "format", "flake-check", "build-nuc", "build-desktop", "clean", "repair"}:
            raise TransportError("Invalid failure stage.")
        lines.append("Failed stage: " + stage)
        if kind == "missing_blocklisted_certificates":
            lines.append("The updated certificate bundle is missing certificates that the blocklist expects to remove; the build stopped. Review the certificate policy against the new bundle.")
        else:
            lines.append("The cause could not be summarized safely; inspect the local failure log.")
    lines.extend([
        "Base: " + (report["base_commit"] or "not recorded"),
        "Candidate: " + (report["candidate_commit"] or "not produced"),
        "Repair attempts: " + str(report["repair_attempts"]) + "; review any candidate changes before use.",
        "Separately pinned applications not automatically updated: " + str(report["independent_pin_count"]),
        "Nothing was installed. Your working checkout was not changed. Activation approval is not enabled.",
        "Report and logs: ~/.local/state/nixos-updates/" + report["id"] + "/",
    ])
    return "\n".join(lines)


def link(client):
    if client.accounts():
        raise TransportError("An account is already linked; no additional account was added.")
    if not sys.stdout.isatty():
        raise TransportError("Run link in a terminal to scan its QR code.")
    result = client.call("startLink")
    uri = result.get("deviceLinkUri") if isinstance(result, dict) else None
    if not isinstance(uri, str) or not uri.startswith("sgnl://linkdevice?"):
        raise TransportError("Invalid linking response.")
    print("On iPhone: Signal > Settings > Linked Devices > Link New Device.", flush=True)
    print("Scan this QR code. Choose Don't Transfer History if offered.", flush=True)
    # Keep the ephemeral linking secret out of command arguments and logs.
    subprocess.run(["qrencode", "-t", "ANSIUTF8"], input=uri, text=True, check=True)
    client.call("finishLink", {
        "deviceLinkUri": uri,
        "deviceName": "NUC Update Reports",
    }, timeout=180)
    client.account()
    print("Linked successfully. Run sudo signal-updates test to check notifications.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["status", "link", "test", "report"])
    args = parser.parse_args()
    client = Client()
    try:
        if args.command == "link":
            link(client)
        elif args.command == "test":
            client.test()
            print("Test submitted to Note to Self. Check delivery and the iPhone notification.")
        elif args.command == "report":
            raw = sys.stdin.buffer.read(65537)
            if len(raw) > 65536:
                raise TransportError("Report exceeds 64 KiB.")
            client.send(format_report(json.loads(raw)))
            print("Build report submitted to Note to Self.")
        else:
            count = len(client.accounts())
            print(f"Signal transport reachable; linked accounts: {count}.")
            if count > 1:
                raise TransportError("Multiple accounts found; delivery tests are disabled.")
    except TransportError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, subprocess.CalledProcessError):
        # RPC errors can include account identifiers or message text; do not echo them.
        print("Signal command failed. Check that the service is running, use sudo, "
              "and ensure exactly one account is linked. A timeout can leave a "
              "completed link or send: check status/Note to Self before retrying.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
