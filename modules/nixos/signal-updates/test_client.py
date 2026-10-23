import contextlib
import io
import json
import os
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

import client


ACCOUNT = {"aci": "11111111-1111-4111-8111-111111111111", "number": None}
SUCCESS = {"timestamp": 123, "results": [{"type": "SUCCESS"}]}


class FakeDaemon:
    """Exercise the actual socket/framing without a real account or network."""

    def __init__(self, handler, connections=1):
        self.directory = tempfile.TemporaryDirectory()
        self.path = self.directory.name + "/rpc.sock"
        self.listener = socket.socket(socket.AF_UNIX)
        self.listener.bind(self.path)
        self.listener.listen()
        self.listener.settimeout(2)
        self.errors = []

        def serve():
            try:
                for _ in range(connections):
                    with self.listener.accept()[0] as connection:
                        with connection.makefile("rb") as stream:
                            request = json.loads(stream.readline())
                        replies = handler(request)
                        for reply in replies:
                            connection.sendall((json.dumps(reply) + "\n").encode())
            except Exception as error:
                self.errors.append(error)

        self.thread = threading.Thread(target=serve)

    def __enter__(self):
        self.thread.start()
        return client.Client(self.path)

    def __exit__(self, *_):
        self.thread.join(3)
        self.listener.close()
        self.directory.cleanup()
        if self.thread.is_alive():
            raise AssertionError("Fake daemon did not finish")
        if self.errors:
            raise self.errors[0]


def response(request, result):
    return {"jsonrpc": "2.0", "id": request["id"], "result": result}


class ClientTests(unittest.TestCase):
    def test_events_and_wrong_ids_are_not_printed_or_returned(self):
        def handler(request):
            return [
                {"method": "receive", "params": {"message": "PRIVATE MESSAGE"}},
                {"id": "unrelated", "result": "PRIVATE MESSAGE"},
                response(request, [ACCOUNT]),
            ]
        output = io.StringIO()
        with FakeDaemon(handler) as transport, contextlib.redirect_stdout(output):
            self.assertEqual(transport.account(), ACCOUNT["aci"])
        self.assertEqual(output.getvalue(), "")

    def test_delivery_is_only_to_self_and_requests_notification(self):
        requests = []

        def handler(request):
            requests.append(request)
            return [response(request, [ACCOUNT] if request["method"] == "listAccounts" else SUCCESS)]

        with FakeDaemon(handler, connections=2) as transport:
            transport.test()
        self.assertEqual(requests[1]["method"], "send")
        self.assertEqual(requests[1]["params"], {
            "account": ACCOUNT["aci"], "noteToSelf": True,
            "notifySelf": True, "message": client.TEST_MESSAGE,
        })

    def test_no_send_for_absent_multiple_or_malformed_accounts(self):
        for accounts in ([], [ACCOUNT, ACCOUNT], [{}], "invalid", [None]):
            with self.subTest(accounts=accounts):
                with FakeDaemon(lambda request: [response(request, accounts)]) as transport:
                    with self.assertRaises(client.TransportError):
                        transport.test()

    def test_rpc_errors_do_not_expose_private_error_details(self):
        def handler(request):
            return [{"id": request["id"], "error": {"message": "PRIVATE MESSAGE"}}]

        with FakeDaemon(handler) as transport:
            with self.assertRaises(client.TransportError) as caught:
                transport.call("listAccounts")
        self.assertNotIn("PRIVATE MESSAGE", str(caught.exception))

    def test_failed_or_partial_delivery_is_not_success(self):
        for result in ({}, {"timestamp": 123}, {"timestamp": 123, "results": []},
                       {"timestamp": 123, "results": [{"type": "NETWORK_FAILURE"}]},
                       {"timestamp": 123, "results": [{"type": "SUCCESS"}, {"type": "IDENTITY_FAILURE"}]}):
            with self.subTest(result=result):
                def handler(request):
                    return [response(request, [ACCOUNT] if request["method"] == "listAccounts" else result)]
                with FakeDaemon(handler, connections=2) as transport:
                    with self.assertRaises(client.TransportError):
                        transport.test()

    def test_closed_connection_is_failure(self):
        with FakeDaemon(lambda request: []) as transport:
            with self.assertRaises(client.TransportError):
                transport.call("listAccounts")

    def test_timeout_is_failure_without_retrying(self):
        def handler(request):
            time.sleep(0.1)
            return []
        with FakeDaemon(handler) as transport:
            with self.assertRaises(TimeoutError):
                transport.call("listAccounts", timeout=0.02)

    def test_link_refuses_existing_account(self):
        with FakeDaemon(lambda request: [response(request, [ACCOUNT])]) as transport:
            with patch("client.subprocess.run") as qr:
                with self.assertRaises(client.TransportError):
                    client.link(transport)
                qr.assert_not_called()

    def test_link_uses_existing_identity_flow_and_private_qr_input(self):
        requests = []
        uri = "sgnl://linkdevice?uuid=ephemeral&pub_key=secret"

        def handler(request):
            requests.append(request)
            results = {"startLink": {"deviceLinkUri": uri}, "finishLink": ACCOUNT}
            result = results.get(request["method"], [] if len(requests) == 1 else [ACCOUNT])
            return [response(request, result)]

        with FakeDaemon(handler, connections=4) as transport:
            with patch("client.sys.stdout.isatty", return_value=True), \
                    patch("client.subprocess.run") as qr, contextlib.redirect_stdout(io.StringIO()):
                # Redirected stdout also needs to behave like the user's terminal.
                with patch("client.sys.stdout.isatty", return_value=True):
                    client.link(transport)
            self.assertEqual(qr.call_args.kwargs["input"], uri)
            self.assertNotIn(uri, qr.call_args.args[0])
        self.assertEqual([r["method"] for r in requests],
                         ["listAccounts", "startLink", "finishLink", "listAccounts"])
        self.assertEqual(requests[2]["params"]["deviceName"], "NUC Update Reports")

    @unittest.skipUnless(os.environ.get("SIGNAL_CLI"), "Set SIGNAL_CLI for real daemon smoke test")
    def test_real_daemon_starts_without_linking_or_registering(self):
        with tempfile.TemporaryDirectory() as directory:
            path = directory + "/rpc.sock"
            with tempfile.TemporaryFile() as log:
                process = subprocess.Popen([
                    os.environ["SIGNAL_CLI"], "--config", directory, "--scrub-log",
                    "daemon", "--socket", path, "--no-receive-stdout", "--ignore-attachments",
                    "--ignore-stories", "--ignore-avatars", "--ignore-stickers",
                ], stdout=log, stderr=log)
                try:
                    for _ in range(150):
                        if os.path.exists(path):
                            break
                        if process.poll() is not None:
                            self.fail("Daemon exited before opening its socket")
                        time.sleep(0.1)
                    self.assertEqual(client.Client(path).accounts(), [])
                finally:
                    process.terminate()
                    process.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
