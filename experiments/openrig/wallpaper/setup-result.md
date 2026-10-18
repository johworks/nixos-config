# Verified team setup

18 October 2026. Beads task: `nixos-txy.4`.

The `weather-wallpaper` rig launched all three configured Codex seats in the
dedicated `feat/weather-wallpaper` worktree. Each reported its live identity,
the intended branch, and readiness. Native configuration uses the isolated
`wallpaper` profile with workspace-write and on-request approvals.

The parent assigned only a read-only coordination check. The team performed
the following sequence without the parent relaying intermediate instructions:

| Stage | Queue record | Result |
| --- | --- | --- |
| Lead | `wallpaper-team-setup-check` | Claimed the parent assignment and created builder work while retaining its own obligation. |
| Builder | `qitem-20261018145242-c1cefb56ed5f96cc` | Ran the existing cellular tests, then handed results to the reviewer. |
| Reviewer | `qitem-20261018145309-fa729c75` | Read the evidence, README and test cases; independently checked the scoped source diff; returned approval to the lead. |
| Lead return | `qitem-20261018145342-6df5c8a6` | Lead read and claimed the returned verdict and closed both its obligations. |

The builder's native tool trace confirms
`node --test wallpapers/cellular/life.test.cjs`. Its recorded result was exit 0,
five passed, zero failed. The reviewer did not rerun that command and labelled
the test outcome as builder evidence. The parent also checked that wallpaper
source files had no changes. The only tracked worktree modification was
OpenRig's managed additions to `AGENTS.md`.

The original lead obligation closed at 14:54:03.420 UTC with downstream IDs and
verification notes. No wallpaper implementation, new implementation Beads,
commits, installation, activation, or live desktop changes were assigned to the
team. It is ready for John's actual discussion.

One attempted reply to `rig send john` failed because the outside human source
is not a managed seat. The lead still returned its answer in its own terminal.
Role guidance was corrected to use the lead conversation for human-facing
answers and canonical seat addresses for internal messages.

The native `rig terminal open weather-wallpaper --window --json` command
reported success for all three conversations and requested a Konsole window.
The tmux viewing session `openrig-view-60877f4e-34a` exists and preserves the
original agent sessions. Window appearance was not independently inspected.

Validation: rig plan/preflight, three live readiness checks, the actual
lead → builder → reviewer → lead path, source-diff inspection, ShellCheck,
`bash -n`, Markdown link checks, and all-host daemon flake check.

This verifies setup and coordination. Implementing a goal received as ordinary
human conversation, repository edits, Nix builds from the team, visual review,
and live-weather behavior are subsequent work.
