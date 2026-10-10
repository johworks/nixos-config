# Codex configuration and MCP servers

`modules/home/codex/default.nix` owns the shared Nix permission profile and the
`codex.mcpServers` Home Manager option. Host `home.nix` files select integrations;
`modules/home/codex/playwright.nix` is enabled only on desktop. Keep reusable
integration declarations next to the Codex module rather than in NixOS service
modules. A service module can still own the server and its runtime secrets.

## Writable configuration

Codex saves preferences and integration settings in `~/.codex/config.toml`.
Do not manage that entire file with `home.file` or `programs.codex.settings`:
those create a read-only Nix store symlink. Our activation script instead merges
the declared settings into a regular file with mode `0600`, using an atomic
replacement and backing up the original as `config.toml.before-nix-permissions`.
Quit Codex before switching to avoid concurrent settings writes.

For MCP servers, Nix owns only the fields explicitly declared under
`codex.mcpServers.<name>`. Other fields, such as Codex's saved enable/disable
choices and OAuth metadata, remain writable and survive activation. Fields
removed from a declaration are removed from the corresponding server. Removing
an entire declaration removes that previously managed server. Servers added
manually under different names remain untouched.

`~/.codex/nix-managed-mcp-servers.json` records the managed server names and field
names so activation can reconcile removals. It contains no setting values.
Keep this file when migrating your Codex configuration to another machine.
Each declared nested value (for example `env`) is owned as a whole.

To add a server, declare its Codex TOML fields in the host or an imported module:

```nix
codex.mcpServers.example = {
  command = lib.getExe pkgs.example-mcp;
  args = [ "--some-option" ];
};
```

Declared values enter the world-readable Nix store. Use runtime wrappers that
read sops-managed files, forwarded environment variable names (`env_vars`), or
Codex's OAuth login for credentials. Do not put tokens in `env` or `http_headers`.
When adopting a manually added server with the same name, remove any conflicting
connection fields first (for example an old `url` when declaring `command`).

## Playwright on desktop

Nixpkgs' `playwright-mcp` supplies matching, patched browsers, so no npm global
install or `playwright install` step is needed. The server runs headless with an
isolated in-memory browser profile, suitable for local development and screenshots.
This controls browser pages; it does not provide native desktop Computer Use.

After building and switching desktop, restart Codex and check the integration:

```sh
sudo nixos-rebuild switch --flake .#desktop
codex mcp list
codex
# In Codex: /mcp
```

Example task:

> Start the development server, use Playwright to open its local URL, reproduce
> the bug, inspect console errors, and verify the fix at desktop and mobile
> viewport sizes. Save screenshots in the project and add a regression test.

For a visible browser, change the declaration to omit `--headless` and start
Codex from your desktop session. Keep `--isolated` for a fresh profile per session.

See the [official Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp)
and [Playwright MCP](https://github.com/microsoft/playwright-mcp).
