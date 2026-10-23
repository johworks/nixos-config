"""Link the private transport and send one inert Note to Self delivery test."""

import argparse
import json
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

    def test(self):
        result = self.call("send", {
            "account": self.account(),
            "noteToSelf": True,
            "notifySelf": True,
            "message": TEST_MESSAGE,
        })
        if not isinstance(result, dict) or type(result.get("timestamp")) is not int:
            raise TransportError("Delivery was not confirmed; check Note to Self before retrying.")
        deliveries = result.get("results")
        if not isinstance(deliveries, list) or not deliveries or any(
            not isinstance(delivery, dict) or delivery.get("type") != "SUCCESS"
            for delivery in deliveries
        ):
            raise TransportError("Signal reported a delivery failure; check Note to Self before retrying.")


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
    parser.add_argument("command", choices=["status", "link", "test"])
    args = parser.parse_args()
    client = Client()
    try:
        if args.command == "link":
            link(client)
        elif args.command == "test":
            client.test()
            print("Test submitted to Note to Self. Check delivery and the iPhone notification.")
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
