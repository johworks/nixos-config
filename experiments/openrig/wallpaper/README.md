# Wallpaper development team

This rig has three Codex agents using `gpt-6.1-sol`:

| Seat | Responsibility |
| --- | --- |
| `dev-lead@weather-wallpaper` | Discuss John's goal, record assignments, coordinate work, and return results. |
| `dev-builder@weather-wallpaper` | Implement bounded assignments in the feature worktree. |
| `dev-reviewer@weather-wallpaper` | Independently review the change and return a verdict to the lead. |

## Talk to the lead

From the main repository root:

```sh
./experiments/openrig/lab exec tmux attach -t dev-lead@weather-wallpaper
```

Type ordinary instructions. For example:

> Let's develop the weather-reacting wallpaper. Start by discussing how sunny,
> cloudy, and rainy conditions could affect the existing cellular wallpaper.
> Once we agree on the behavior, have the builder make a simulated prototype
> and have the reviewer check it. Bring me the result before activating it.

The lead handles queue bookkeeping and specialist handoffs. You can discuss
options and change direction in that same conversation. Detach with **Ctrl-b,
then d**; the team stays running.

To open all three agents in one terminal window:

```sh
./experiments/openrig/lab terminal open weather-wallpaper --window
```

Click a pane to focus it, or use **Alt + arrow keys** to move between panes.
The standard **Ctrl-b, then an arrow key** also works. The lab keeps these
settings in its own [tmux configuration](../tmux.conf).

The TUI is the monitoring interface:

```sh
./experiments/openrig/lab tui
```

You can inspect any specialist's terminal too, but give team goals to the lead.
This team does not need the automatic idea-inbox classifier to accept a goal.

## Workspace and state

The feature branch is `feat/weather-wallpaper`, checked out at
`experiments/openrig/.local/wallpaper-worktree`. It is a linked worktree of this
repository; Git history and the Beads database are shared, while working files
are separate. Only the builder should edit implementation files. The lead and
reviewer coordinate and inspect unless explicitly assigned an edit.

OpenRig adds managed guidance to that worktree's `AGENTS.md`. Those additions
are local startup state and should stay out of implementation commits. The
team's authored role instructions live in [agent/roles.md](agent/roles.md).
The original notes researcher remains available in its separate lab workspace.

The native `wallpaper` Codex configuration profile lives in the lab provider
home. It keeps workspace-write and on-request approvals and adds the user Nix
cache and the repository's shared Git directory as writable paths. It does not
change John's normal Codex configuration. The model and login are the same ones
already exercised in the lab. Provider approval requests can still appear in
the requesting agent's terminal; a lead cannot approve them just by messaging.

## Prepare and start again

After installing the base lab and signing in, prepare the worktree and profile:

```sh
./experiments/openrig/wallpaper/setup
```

If the local daemon is stopped, start it with
`./experiments/openrig/lab daemon start --no-kernel --host 127.0.0.1 --port 17433`
before launching or restoring the team.

This checks the branch, creates the worktree/profile only when absent, and
previews the rig. For the first launch:

```sh
./experiments/openrig/lab up "$PWD/experiments/openrig/wallpaper/rig.yaml"
```

For a stopped existing team, restore its saved conversations instead:

```sh
./experiments/openrig/lab up weather-wallpaper --existing
```

To pause the team, first make sure it has finished or recorded its current work:

```sh
./experiments/openrig/lab down weather-wallpaper --snapshot
```

## What was assigned at setup

Only the [read-only coordination check](coordination-check.md) was assigned.
It exercises lead → builder → reviewer → lead with the existing simulation
tests. Wallpaper implementation waits for John's discussion with the lead.
See the [recorded setup result](setup-result.md) for the observed handoffs and
verification limits.
