#!/usr/bin/env bash
# Exercise the running containers' own TLS clients without changing their state.
set -euo pipefail

if (( EUID != 0 )); then
  echo "Run on the NUC: sudo bash scripts/check-container-certificates.sh" >&2
  exit 1
fi

failed=0
for container in home-assistant esphome; do
  echo "=== $container ==="
  if ! podman exec --interactive --env PYTHONDONTWRITEBYTECODE=1 "$container" python3 - <<'PY'
import concurrent.futures
import importlib.metadata
import ssl
import sys
import urllib.error
import urllib.request

import certifi
import pip._vendor.certifi
import requests

print("Python", sys.version.split()[0], flush=True)
for package in ("homeassistant", "esphome", "certifi", "pip", "requests"):
    try:
        print(package, importlib.metadata.version(package), flush=True)
    except importlib.metadata.PackageNotFoundError:
        pass
print("certifi bundle:", certifi.where(), flush=True)
print("pip bundle:", pip._vendor.certifi.where(), flush=True)

urls = [
    "https://dv-g3b-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-aaa-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-noct-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-aaa-noct-emudhra.we-have-a-problem.com/",
    "https://example.com/",
]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        return None


def check(case):
    engine, url = case
    control = url == urls[-1]
    try:
        if engine == "requests":
            with requests.get(url, timeout=15, stream=True, allow_redirects=False) as response:
                status = response.status_code
        else:
            context = ssl.create_default_context()
            if engine == "certifi":
                context = ssl.create_default_context(cafile=certifi.where())
            elif engine == "pip-certifi":
                context = ssl.create_default_context(cafile=pip._vendor.certifi.where())
            opener = urllib.request.build_opener(
                NoRedirect(), urllib.request.HTTPSHandler(context=context)
            )
            with opener.open(url, timeout=15) as response:
                status = response.status
        result = "PASS" if control and status == 200 else "FAIL"
        detail = f"HTTP {status}"
    except urllib.error.HTTPError as error:
        # An HTTP response proves the TLS handshake succeeded, even for a 4xx.
        result, detail = "FAIL", f"HTTP {error.code}"
    except Exception as error:
        detail = str(error)
        certificate_error = "CERTIFICATE_VERIFY_FAILED" in detail
        if certificate_error:
            result = "FAIL" if control else "PASS"
        else:
            result = "INCONCLUSIVE"
    return result, f"{result} {engine} {url} {detail}"


cases = [(engine, url) for engine in ("urllib", "requests", "certifi", "pip-certifi") for url in urls]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results = list(pool.map(check, cases))
for result, message in results:
    print(message, flush=True)
passed = sum(result == "PASS" for result, _ in results)
print(f"{passed}/{len(results)} TLS checks passed", flush=True)
sys.exit(0 if passed == len(results) else 1)
PY
  then
    failed=1
  fi
done

if (( failed )); then
  echo "Container verification incomplete: inspect FAIL or INCONCLUSIVE results above." >&2
  exit 1
fi
echo "Both containers passed all 40 TLS checks."
