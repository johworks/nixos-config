# Flake Cleanup Plan

## Purpose

This document defines the cleanup plan for the NixOS configuration repo.
It exists to keep the refactor focused, incremental, and easy to understand.

Primary goal: make the repo more legible and easier to reason about later.

This cleanup favors:

- clear intent over cleverness
- explicit wiring over hidden magic
- small reviewable phases over one large rewrite
- understanding over maximum technical abstraction

## Current Working Rules

- Work on branch `cleanup-flake-clarity`
- Make changes in small logical phases
- Rebuild and switch on `laptop` after each completed phase
- Do not combine unrelated cleanup into the same phase
- Prefer obvious naming and shallow structure
- Avoid fancy auto-import patterns or dynamic module discovery

## Non-Goals

These are explicitly out of scope unless they become necessary:

- redesigning every host from scratch
- introducing advanced flake frameworks
- turning the repo into a highly abstract module system
- changing `system.stateVersion` just because channels change
- moving secrets management around unless required for clarity
- large service rewrites unrelated to the flake cleanup

## Desired End State

The repo should be understandable in three layers:

1. `flake.nix` chooses inputs, channels, and host construction.
2. `hosts/<name>/configuration.nix` describes what that machine is.
3. `modules/nixos/common/*.nix` provides a small set of shared defaults.

The flake should answer:

- which channel each host uses
- which common modules are shared
- which special arguments are available to modules

Host configs should answer:

- what this machine does
- what hardware or boot quirks it has
- what desktop or server role it plays
- what host-specific packages or services it needs

Shared modules should answer:

- what defaults are common enough to centralize
- what maintenance policy applies to a class of systems

## Channel Policy

Keep channel choice explicit and easy to read.

- `laptop`: unstable
- `desktop`: unstable
- `vm`: unstable
- `nuc`: stable release branch

Use unstable as the main package set for workstation-style systems.
Use stable as the main package set for the NUC/router-server system.

If a stable host needs a newer package, allow a narrow explicit unstable escape hatch.
Do not re-import separate nixpkgs instances all over host files without a clear reason.

Naming rule:

- prefer `nixpkgs-unstable` and `nixpkgs-stable`
- avoid vague names like `latestPkgs`

## Structural Plan

Target structure:

- `flake.nix`
- `hosts/<name>/configuration.nix`
- `hosts/<name>/home.nix`
- `modules/nixos/common/base.nix`
- `modules/nixos/common/workstation.nix`
- `modules/nixos/common/maintenance.nix`
- optional `modules/nixos/common/user-john.nix`

Keep the number of common modules small.
Only extract a shared module when it improves readability.

## Planned Shared Module Responsibilities

`modules/nixos/common/base.nix`

- timezone
- locale
- flakes / nix-command settings
- `allowUnfree`
- small truly-global defaults

`modules/nixos/common/workstation.nix`

- desktop/laptop/vm defaults
- printing
- pipewire
- other shared workstation behavior

`modules/nixos/common/maintenance.nix`

- garbage collection
- store optimization
- rollback-related retention policy

`modules/nixos/common/user-john.nix` if useful

- shared baseline for the `john` user
- only if it keeps host files shorter and clearer

## Maintenance Policy

Separate two concerns clearly:

- store cleanup
- bootable rollback entry retention

Planned defaults:

For `laptop` and `desktop`:

- enable automatic GC
- prefer weekly cleanup
- delete older generations/store data after a moderate window
- enable automatic store optimization
- keep boot entries limited where supported

For `nuc`:

- enable automatic GC conservatively
- keep a larger rollback window
- keep several bootable configurations available

Exact values can be chosen during implementation, but the intent is:

- workstations stay tidy automatically
- the NUC remains more conservative and rollback-friendly

## Refactor Phases

### Phase 1: Simplify flake inputs and host construction

Goal:

- remove duplicate channel definitions
- make host channel selection explicit
- reduce repeated `nixosSystem` boilerplate

Expected changes:

- rename inputs for clarity
- remove duplicate unstable input naming
- add one small `mkHost` helper if it improves readability
- pass shared args from one place

Validation:

- `nix flake check`
- rebuild and switch `laptop`

### Phase 2: Centralize module wiring

Goal:

- choose one place to wire Home Manager and shared module args

Expected changes:

- remove duplicate Home Manager module imports from host files
- keep module wiring either in the flake or in one obvious layer
- prefer the flake owning cross-host wiring

Validation:

- `nix flake check`
- rebuild and switch `laptop`

### Phase 3: Add shared common modules

Goal:

- move repeated base settings into a few obvious shared modules

Expected changes:

- create `base.nix`
- create `workstation.nix`
- optionally create `user-john.nix`
- keep files short and explicit

Validation:

- `nix flake check`
- rebuild and switch `laptop`

### Phase 4: Add maintenance policy

Goal:

- make cleanup behavior explicit and host-appropriate

Expected changes:

- add GC and optimization defaults
- add workstation vs NUC retention policy
- document rollback intent in comments where needed

Validation:

- `nix flake check`
- rebuild and switch `laptop`

### Phase 5: Remove dead structure and stale patterns

Goal:

- reduce noise and ambiguity

Expected changes:

- archive or remove `hosts/default`
- remove unused bindings
- remove commented fragments that no longer serve a purpose
- rename vague identifiers like `latestPkgs`

Validation:

- `nix flake check`
- rebuild and switch `laptop`

## Review Rules During Implementation

Before merging a phase, confirm:

- the change has one clear purpose
- the diff is still easy to read top to bottom
- names describe intent, not implementation trivia
- the host files remain readable without jumping through many layers
- no abstraction was added just to reduce line count

## Laptop-First Workflow

We are currently working from `laptop`.

For each phase:

1. Make one logical change set.
2. Run formatting.
3. Run `nix flake check`.
4. Rebuild the laptop host.
5. Switch the laptop host if the build is sound.
6. Only then move to the next phase.

Commands to use during implementation:

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.laptop.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#laptop
```

If a phase touches host selection or shared module wiring, validate that phase before continuing.

## Notes

When in doubt, prefer the version that is easier to understand six months from now.
If a shared abstraction makes the repo harder to read, keep the config more explicit even if it duplicates a small amount of code.
