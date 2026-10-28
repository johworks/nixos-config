# Repository Guidelines

This flake uses NixOS with Home Manager as a NixOS module. Bias changes toward clarity over cleverness: small diffs, explicit intent, and configurations that future-you can read fast.

K.I.S.S (Keep It Simple Stupid)

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
- For new files referenced by the flake, use `git add -N <path>` so Nix can see them during eval/build without staging contents.
- After edits: run formatting, then a quick eval/check.
- Track temporary fixes and review them during input updates using `docs/temporary-fixes.md`; record findings and the next review date in Beads.

## Commands
- Evaluate/check: use `nix --store daemon eval --no-write-lock-file ...`; `nix --store daemon flake check --no-write-lock-file`; quick view `nix --store daemon flake metadata --no-write-lock-file`.
- Build host (no switch): `nix --store daemon build --no-write-lock-file .#nixosConfigurations.<host>.config.system.build.toplevel`
- Routine Nix evaluation, checks, and builds use the daemon without sudo. Codex's `nix-workspace` permission profile allows the user cache, daemon socket, and workspace `.git` writes; restart Codex after changing its permissions.
- Switch host: `sudo nixos-rebuild switch --flake .#<host>`

## Testing & Validation
- Run `nix flake check` before switching; fix evaluation errors first.
- For new services/modules, ensure `systemd` targets make sense and the module is intentionally enabled.
- For Hyprland changes, use the guest workflow in `docs/hyprland-lab.md`:
  deploy to the lab, run `hyprlab verify`, and inspect the generated screenshots.
  Exercise the UI states affected by the change; passing shell checks or merely
  creating images does not establish visual correctness. Keep physical host
  session changes separate from guest experiments.

## Task Tracking
- Use Beads (`bd`) for project tasks; state lives in the NUC's shared Dolt database.
- Start with `bd ready --json`; claim work with `bd update <id> --claim` before editing.
- Record findings and handoffs in the task, and close it only after verification.
- Run `bd dolt commit` after a completed unit of work to checkpoint task history.
- Clients share live state: do not run `bd dolt push`, `bd dolt pull`, or `bd bootstrap` for this repo.
- If the server is unavailable, restore the SSH tunnel instead of initializing a local database.
- Connection, actor identity, and recovery instructions are in `docs/beads.md`.

## Secrets
- `.sops.yaml` encrypts `secrets/*.env` and `secrets/secrets.yaml` with age key `age18t746d…w4jy`.
- Encrypt/edit: `sops secrets/<name>.env`. Never commit plaintext; use `sops-nix` references.

## Commits & PRs
- Use concise, sentence-style summaries noting scope/host when relevant (e.g., “Update DDNS for nuc”).
- One logical change per commit. Include what changed, why, and commands run (`nix flake check`, build/switch target). Add screenshots only if UI-facing. 

## Working With Git
- Create a feat/ branch for implementing new features
- Rebase onto main, and merge without a PR (for now)
- Make sure to stay up to date with main so we don't drift (shouldn't be an issue if we keep features well scoped)
