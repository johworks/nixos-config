{
  config,
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (packages: [ packages.tomlkit ]);
  toml = pkgs.formats.toml { };
  settings = toml.generate "codex-nix-settings.toml" {
    mcp_servers = config.codex.mcpServers;
    default_permissions = "nix-workspace";
    approval_policy = "on-request";
    shell_environment_policy.set.NIX_REMOTE = "daemon";
    permissions.nix-workspace = {
      extends = ":workspace";
      filesystem = {
        "/nix/store" = "read";
        "${config.home.homeDirectory}/.cache/nix" = "write";
        "/nix/var/nix/daemon-socket" = "read";
        # Allow Git operations without lifting the rest of the workspace sandbox.
        ":workspace_roots".".git" = "write";
      };
      network = {
        # Flake sources and dependencies may need client-side downloads.
        enabled = true;
        unix_sockets."/nix/var/nix/daemon-socket/socket" = "allow";
      };
    };
  };
in
{
  options.codex.mcpServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf toml.type);
    default = { };
    description = ''
      MCP server fields merged into Codex's writable config.toml at activation.
      Declared fields are managed by Nix; other fields and servers are preserved.
      Removing a server declaration removes that previously managed server.
      Keep credentials out of these settings, which are stored in the Nix store.
    '';
  };

  config = {
    assertions = [
      {
        assertion =
          !(config.home.file ? ".codex/config.toml") || !config.home.file.".codex/config.toml".enable;
        message = "Codex config.toml must remain writable; use codex.mcpServers instead of home.file or programs.codex.settings.";
      }
    ];

    # Codex appends remembered approvals to default.rules; keep that file mutable.
    home.file.".codex/rules/nixos.rules".source = ./nixos.rules;
    home.file.".codex/skills/blog-entry".source = ./skills/blog-entry;

    # Merge into a regular file because Codex also saves settings in config.toml.
    home.activation.codexNixPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${python}/bin/python3 ${./configure.py} \
        ${lib.escapeShellArg config.home.homeDirectory} ${settings}
    '';
  };
}
