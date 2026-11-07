# Repository Guidelines

This flake manages NixOS hosts and Home Manager. Prefer simple, focused changes
that are easy to read and review. Keep modules cohesive, put host-specific
settings in the host, and comment non-obvious intent.

This repository is public. Take care not to expose private information in
configuration, documentation, logs, or commit history.

## Layout

- `flake.nix` defines the host configurations; `hosts/` holds their settings.
- `modules/nixos/` and `modules/home/` hold shared modules.
- `wallpapers/` holds assets; `secrets/` holds encrypted secrets.

## Workflow

- If Beads is available, use it for project tasks: check `bd ready --json`,
  claim work, record findings, close after verification, and run
  `bd dolt commit`. See `docs/beads.md` for this repo's shared database and
  recovery workflow; do not run `bd dolt push`, `bd dolt pull`, or
  `bd bootstrap` here. Otherwise, proceed without Beads.
- Record agent friction encountered in the NixOS environment in Beads, including
  context, symptoms, and any workaround; if Beads is unavailable, create or
  update `docs/agent-friction.md` for follow-up.
- For new files referenced by the flake, use `git add -N <path>` so Nix can
  see them during evaluation.
- Format changes and run checks appropriate to their scope. Use the Nix daemon
  without sudo and `--no-write-lock-file` for routine evaluation and builds.
  Run `nix --store daemon flake check --no-write-lock-file` before switching.
- For Hyprland changes, follow `docs/hyprland-lab.md` and visually inspect the
  affected states in the guest, separate from the physical host session.
- Use Nix-managed configuration for host changes, including experiments. If an
  unmanaged change is necessary, communicate it and clean it up when done unless
  requested otherwise. Remove conflicting trial services and shortcuts before
  activating a replacement, then verify the replacement and its controls.
- Track temporary fixes and review them during input updates as described in
  `docs/temporary-fixes.md`, recording findings and the next review in Beads
  when available.
- Keep secrets encrypted with SOPS and reference them through sops-nix; never
  commit plaintext.

## Git

Use focused commits with concise summaries. Create a `feat/` branch for new
features, keep it current with main, and merge without a PR.
