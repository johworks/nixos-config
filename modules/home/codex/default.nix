{
  config,
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (packages: [ packages.tomlkit ]);
  permissions = (pkgs.formats.toml { }).generate "codex-nix-permissions.toml" {
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
  # Codex appends remembered approvals to default.rules; keep that file mutable.
  home.file.".codex/rules/nixos.rules".source = ./nixos.rules;
  home.file.".codex/skills/blog-entry".source = ./skills/blog-entry;

  # Merge into a regular file because Codex also saves settings in config.toml.
  home.activation.codexNixPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${python}/bin/python3 ${./configure.py} \
      ${lib.escapeShellArg config.home.homeDirectory} ${permissions}
  '';
}
