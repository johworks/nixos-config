# Matrix notes

This module runs Synapse for `goobhub.org`.

## Current registration mode

Registration is enabled, but only with a Synapse registration token.

Relevant config:

- `enable_registration = true;`
- `registration_requires_token = true;`

Federation is still disabled, so this remains a private homeserver.

## Apply the config

```bash
sudo nixos-rebuild switch --flake .#nuc
```

## Admin access token

Synapse does not have a separate "admin token" concept here. You use a normal Matrix access token from an account that has Synapse admin privileges.

To get one, log in via the client API:

```bash
export HS="https://matrix.goobhub.org"

curl -sS -X POST "$HS/_matrix/client/v3/login" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "m.login.password",
    "identifier": {
      "type": "m.id.user",
      "user": "your-admin-username"
    },
    "password": "your-admin-password"
  }'
```

The response includes an `access_token`. Use that as `ADMIN_TOKEN`.

```bash
export ADMIN_TOKEN="paste_access_token_here"
```

## Create a one-time registration token

```bash
curl -sS -X POST "$HS/_synapse/admin/v1/registration_tokens/new" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uses_allowed":1}'
```

To choose the token value yourself:

```bash
curl -sS -X POST "$HS/_synapse/admin/v1/registration_tokens/new" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token":"friend-alice-001","uses_allowed":1}'
```

## Reset a user's password

```bash
curl -sS -X POST "$HS/_synapse/admin/v1/reset_password/@alice:goobhub.org" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"new_password":"choose-a-new-password","logout_devices":true}'
```

## Deactivate a user

Synapse's supported admin action is account deactivation. This disables the account and prevents login.

Deactivate without erasing:

```bash
curl -sS -X POST "$HS/_synapse/admin/v1/deactivate/@alice:goobhub.org" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Deactivate and mark the account as erased:

```bash
curl -sS -X POST "$HS/_synapse/admin/v1/deactivate/@alice:goobhub.org" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase":true}'
```

`erase: true` is closer to a GDPR-style erase than a literal "delete this row from the database".

## Signup flow for friends

1. Point the client at `matrix.goobhub.org`.
2. Choose username and password.
3. Enter the registration token.
4. Finish signup.

## Password recovery

Right now there is no self-service forgot-password flow in this repo because Synapse email/SMTP is not configured.

Until SMTP is added, recovery means either:

- the user changes their password while still logged in on a device, or
- an admin resets it with the API above.
