"""Exercise the real trust-store builder against old and new NSS data."""

import pathlib
import re
import ssl
import subprocess
import sys
import tempfile

builder, certdata, filtered_bundle = sys.argv[1:]
blocked = ["Comodo AAA Services root", "emSign ECC Root CA - G3",
           "emSign Root CA - C1", "emSign ECC Root CA - C3"]
with tempfile.TemporaryDirectory() as directory:
    directory = pathlib.Path(directory)
    blocklist = directory / "blocklist"
    output = directory / "bundle.crt"
    blocklist.write_text("\n".join(blocked) + "\n")
    command = [builder, "--certdata_input", certdata, "--blocklist", str(blocklist),
               "--ca_bundle_output", str(output)]
    subprocess.run(command, check=True)
    for path in (output, filtered_bundle):
        context = ssl.create_default_context(cafile=str(path))
        names = {value for cert in context.get_ca_certs() for part in cert["subject"]
                 for key, value in part if key == "commonName"}
        assert "ISRG Root X1" in names, "ordinary trusted roots must remain available"
        # OpenSSL can retain a root with explicit reject metadata. Verify each
        # matching root instead of treating its presence as proof of trust.
        pkcs7 = subprocess.run(["openssl", "crl2pkcs7", "-nocrl", "-certfile", str(path)],
                               check=True, capture_output=True).stdout
        pem = subprocess.run(["openssl", "pkcs7", "-print_certs"], input=pkcs7,
                             check=True, capture_output=True).stdout
        checked = set()
        for certificate in re.findall(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.S):
            root = directory / "root.pem"
            root.write_bytes(certificate + b"\n")
            decoded = ssl._ssl._test_decode_cert(str(root))
            common_names = {value for part in decoded["subject"] for key, value in part if key == "commonName"}
            if common_names.intersection({"AAA Certificate Services", *blocked}):
                checked.update(common_names)
                result = subprocess.run(["openssl", "verify", "-purpose", "sslserver", "-CAfile", str(path), str(root)],
                                        capture_output=True, text=True)
                assert result.returncode != 0 and "certificate rejected" in result.stderr, (
                    f"blocked root was not explicitly rejected: {common_names}: {result.stderr}"
                )
        assert "AAA Certificate Services" in checked, "AAA distrust was not exercised"

    blocklist.write_text("\n".join([*blocked, "not-a-real-root-for-regression-test"]) + "\n")
    failure = subprocess.run(command, capture_output=True, text=True)
    assert failure.returncode == 3, failure.stderr
    assert "not-a-real-root-for-regression-test" in failure.stderr
