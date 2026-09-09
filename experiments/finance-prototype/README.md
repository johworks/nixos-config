# Finance Prototype

Local-first personal finance prototype with a small web UI and a Teller import path.

The app stores imported data as JSON under `FINANCE_DATA_DIR`. Teller credentials are
read only from environment variables so certs, keys, and access tokens do not enter
the Nix store.

## Run

```sh
nix run .#finance-prototype
```

Then open:

```text
http://127.0.0.1:8077
```

## NixOS Module

The `nuc` host enables the prototype through `services.financePrototype`.
It binds to all interfaces and opens TCP port 8077 for LAN development:

```nix
services.financePrototype = {
  enable = true;
  bindAddress = "0.0.0.0";
  openFirewall = true;
};
```

Apply it with:

```sh
sudo nixos-rebuild switch --flake .#nuc
```

Then open:

```text
http://192.168.10.1:8077
```

For local hacking:

```sh
nix develop .#finance-prototype
node experiments/finance-prototype/src/server.mjs
```

## Teller Import

Required environment variables:

```sh
export TELLER_APPLICATION_ID=app_xxxxxx
export TELLER_CERT_PATH=/run/secrets/teller-cert.pem
export TELLER_KEY_PATH=/run/secrets/teller-key.pem
```

`TELLER_ACCESS_TOKENS` is optional once enrollments are saved through the UI.

For `sops-nix`, prefer one encrypted dotenv file with inline PEM values:

```sh
TELLER_ACCESS_TOKENS=access_token_one,access_token_two
TELLER_APPLICATION_ID=app_xxxxxx
TELLER_CERT_PEM="-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
TELLER_KEY_PEM="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Then wire it into the NixOS module:

```nix
services.financePrototype = {
  enable = true;
  bindAddress = "0.0.0.0";
  openFirewall = true;
  useSops = true;
  sopsFile = ./secrets/finance-prototype.env;
};
```

Optional:

```sh
export FINANCE_DATA_DIR=/var/lib/finance-prototype
export FINANCE_ADDR=127.0.0.1:8077
export FINANCE_LOOKBACK_DAYS=45
```

Click **Import** in the UI or call:

```sh
curl -X POST http://127.0.0.1:8077/api/import/teller
```

The importer:

- opens Teller Connect in the browser when `TELLER_APPLICATION_ID` is set
- saves successful enrollment access tokens in `FINANCE_DATA_DIR/enrollments.json`
- lists Teller accounts for each access token
- imports transactions for accounts that expose a transactions link
- uses `start_date` with a configurable lookback window
- upserts transactions by Teller transaction ID

## What Is Needed From Teller

- Teller developer account
- Teller application ID
- client certificate file
- private key file

## Teller Signup Blocker

As of 2026-06-13, we could not find a working public Teller developer signup
flow.

What we verified:

- Teller's current homepage links to docs, legal, blog, sign-in, and X/Twitter,
  but not signup.
- `https://teller.io/session` is login-only.
- Common signup/contact routes returned 404:
  - `https://teller.io/signup`
  - `https://teller.io/register`
  - `https://teller.io/user/new`
  - `https://teller.io/sales`
- `https://teller.io/dashboard` redirects to login.
- The Teller examples repo still requires `APP_ID=app_xxx`; it does not create a
  Teller developer account.
- Teller's quickstart says the Application ID comes from Dashboard Application
  Settings and certs come from Dashboard Certificates / `teller.zip`.
- An older Teller blog page linked "Create a free developer account" to
  `https://teller.io/user/new`, but that route now returns 404.

Current conclusion:

- Teller previously appears to have had public self-serve developer signup, but
  the public route is now removed or disabled.
- The existing Teller code can still work if we obtain a developer account,
  Application ID, cert, and private key.
- Until then, Teller is blocked before sandbox or live imports can be tested.

Likely next options:

- Contact Teller through their visible public channel and ask how to access the
  Developer tier.
- Add SimpleFIN as a second provider so real transaction import can proceed
  without waiting on Teller access.
