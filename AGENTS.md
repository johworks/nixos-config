# Repository Guidelines

This flake uses NixOS with Home Manager as a NixOS module. Bias changes toward clarity over cleverness: small diffs, explicit intent, and configurations that future-you can read fast.

## High-level Principles
- Keep modules small, one concern each; avoid new directory conventions without cause.
- Comment intent (why) when a value is non-obvious; skip obvious what-comments.
- Minimize indirection and `lib.*` trickery unless it clearly reduces complexity.
- Make changes safe to review: focused commits, avoid repo-wide refactors unless requested.

## Project Structure
- Root: `flake.nix` exports `nixosConfigurations` for `laptop` and `nuc`.
- Hosts: `hosts/<name>/{configuration.nix,hardware-configuration.nix,home.nix}`; Home Manager is configured through NixOS.
- Shared modules: `modules/nixos/*` (e.g., `ddns`, `vaultwarden`, `bedrock`, `zurg`, `myapp`, `josh`); user modules in `modules/home/*` (`nvim`, `profiles`, etc.).
- Assets: `wallpapers/`. Secrets belong in `secrets/` and stay encrypted.

## Style & Naming
- Nix: two-space indent, prefer plain attribute sets, use `let … in` only when it improves readability.
- Module files should describe what they do (`vaultwarden/default.nix`), with options namespaced per module; host names stay lowercase.
- Add comments for hardware quirks or non-obvious settings, not for trivial enables.

## Workflow (Before / During / After)
- Pick a single goal; apply it in the most local place (host first, shared only if reused).
- Keep diffs small; if touching multiple hosts, say why in the commit.
- After edits: run formatting, then a quick eval/check.

## Commands
- Format (if defined): `nix fmt`; otherwise `nix run nixpkgs#nixfmt-rfc-style -- .`
- Evaluate/check: `nix flake check`; quick view `nix flake show`.
- Build host (no switch): `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Switch host: `sudo nixos-rebuild switch --flake .#<host>`

## Testing & Validation
- Run `nix flake check` before switching; fix evaluation errors first.
- For new services/modules, ensure `systemd` targets make sense and the module is intentionally enabled.

## Secrets
- `.sops.yaml` encrypts `secrets/*.env` and `secrets/secrets.yaml` with age key `age18t746d…w4jy`.
- Encrypt/edit: `sops secrets/<name>.env`. Never commit plaintext; use `sops-nix` references.

## Commits & PRs
- Use concise, sentence-style summaries noting scope/host when relevant (e.g., “Update DDNS for nuc”).
- One logical change per commit. Include what changed, why, and commands run (`nix flake check`, build/switch target). Add screenshots only if UI-facing. 
