# OpenRig learning lab

Learn the existing tool before building the idea notebook. This is a local
OpenRig experiment with one researcher, an example idea, and a context pack.

For the everyday conversation and assignment paths, start with
[How to talk to OpenRig](INTERFACE.md).

OpenRig **0.6.11**, source commit
`379f0a0d106e65164c615818927267c2082ebcb4`, is pinned for this investigation.
The lab uses Node 24.14.1, tmux 3.6a from the repository's locked unstable
input, and Codex CLI 0.163.0. The researcher uses `gpt-6.1-sol`, the model
selected in John's existing Codex configuration when the lab was created.

## What we verified

On 18 October 2026, the local lab completed these checks:

| Check | Result |
| --- | --- |
| Install and native SQLite | Pinned npm package runs on this NixOS desktop with Node 24. |
| Intake retry | Submitting the same stream ID and body twice returned the same record and timestamp. |
| Classification | A manually supplied classification was saved under a lease. Retrying it returned `idempotency_violation` with the existing classification ID; it did not silently return success. |
| Agent pickup | A real Codex session read and claimed the assigned queue item after the daemon's nudge. |
| Context | Retrieving `notes-lab/notes.md#goal` returned only that Markdown section. |
| First result | The researcher wrote [a report](findings/first-experiment.md) and linked it from the queue closure. |
| Daemon restart | The idea, completed task/history, context, and report remained available after shutdown and restart. |
| Snapshot restore | The stopped seat was reported `resumed`; its prior conversation was visible, and it completed [a linked follow-up](findings/continuity.md) using the previous report. |
| Dashboard | The TUI rendered the live lab topology in a PTY. No desktop terminal window was opened. |

The follow-up brief supplied the earlier report's path. This demonstrates warm
restore and directed reuse, not independent discovery of relevant notes. A host
reboot, cold conversation, continuous classification loop, and phone capture
remain untested.

The largest open product questions are how new captures trigger processing,
when an idea merits an experiment, how relevant findings are selected, and how
the results become useful notebook pages. The CLI exposes lower-level tools
for much of this; those user-facing behaviors need a defined workflow and tests.

Two rough edges appeared. `doctor --spec rig.yaml` reports unhealthy because
Claude Code is absent even though the Codex-only seat works and spec conformance
passes. Installing the unused provider is not required by this lab. Restore
also emitted guidance-repair warnings; inspection afterward confirmed all five
named managed guidance blocks were present in the lab's `AGENTS.md`.

## Try the running lab

From the repository root, open the dashboard:

```sh
./experiments/openrig/lab tui
```

The topology contains `notes-lab`. Expand it to see the researcher and its work.
The dashboard is for observing and navigating; the agent's conversation is in
its terminal. In another terminal, join that conversation:

```sh
./experiments/openrig/lab exec tmux attach -t notes-researcher@notes-lab
```

Detach with **Ctrl-b, then d**; the agent keeps running. The lab wrapper selects
the correct private tmux server, so use it for attachment too.

A useful first message to type is:

> Walk me through the first experiment, show me the saved findings, and explain
> which steps OpenRig handled and which steps we supplied. Do not start new work.

These commands inspect the records directly:

```sh
./experiments/openrig/lab stream show notes-lab-001 --json
./experiments/openrig/lab project list --json
./experiments/openrig/lab queue show notes-lab-first-report --full --json
./experiments/openrig/lab queue transitions notes-lab-first-report --json
./experiments/openrig/lab context get 'notes-lab/notes.md#goal'
./experiments/openrig/lab capture notes-researcher@notes-lab --lines 40
```

## The pieces to understand

| Piece | Meaning in this experiment |
| --- | --- |
| Rig | The saved `notes-lab` configuration and running group. |
| Pod | The `notes` group inside that rig. |
| Seat | The stable role `notes-researcher@notes-lab`; a conversation occupies it. |
| Stream | Original observations, including `notes-lab-001`. They need not become work. |
| Project classification | Labels and routing attached to an observation, under a classifier lease. Here `project` means classification, not a Git repository. |
| Queue item | Work owned by a seat, with claims, status, and transition history. |
| Context pack | Files made addressable to agents, including individual Markdown sections. |
| Finding | An authored Markdown artifact. Our assignment asks the agent to write it; a queue row alone is not a research result. |

The first experiment uses this sequence:

1. The parent session saves an idea with `rig stream emit` and a stable ID.
2. The parent acquires a classifier lease and supplies the idea's labels.
3. The parent assigns `first-experiment.md` as a queue item. OpenRig nudges the
   destination; the researcher reads and claims the saved assignment.
4. The researcher reads the idea and relevant context, checks the installed
   command surfaces, writes a report, and records where the result went.

This deliberately separates manually supplied setup from actual agent behavior.
It does not establish an unattended capture-to-experiment service.

## Installation and isolation

The lab is already installed on this desktop. For a fresh checkout, first have
Node 22 or 24, npm, Nix, and an authenticated Codex CLI available, then run:

```sh
./experiments/openrig/lab install
./experiments/openrig/lab exec codex login
./experiments/openrig/lab daemon start --no-kernel --host 127.0.0.1 --port 17433
./experiments/openrig/lab context add "$PWD/experiments/openrig/context"
./experiments/openrig/lab config set ui.timezone America/New_York
./experiments/openrig/lab up "$PWD/experiments/openrig/rig.yaml" --plan
./experiments/openrig/lab up "$PWD/experiments/openrig/rig.yaml"
```

`install` installs the pinned CLI locally and retains tmux through a Nix output
link. npm resolves transitive dependencies on the first install; this is an
exploratory installation, not a fully locked Nix package. It uses the existing
Node and Codex executables on `PATH`.

The wrapper puts state beneath the ignored, private `.local/` directory:

- `state/`: SQLite database, context library, logs, and OpenRig configuration.
- `home/`: isolated provider configuration, skills, credentials, and sessions.
- `workspace/`: the disposable agent working directory and generated findings.
- `tmux/`: a separate terminal server's socket directory.
- `package/`: the local npm installation.

The initial run used a private copy of the existing Codex file credentials.
Credentials and generated provider state stay ignored; a fresh checkout signs
in through the isolated environment. OpenRig may modify the lab's provider
hooks and trust settings. The home override keeps those writes out of John's
normal provider configuration. This is configuration isolation, not a container
or a guarantee against arbitrary host access.

The listener is explicitly loopback-only at `127.0.0.1:17433`. The optional
web interface is off. The kernel, OpenRig's own operator/advisor team, is also
off: this bounded experiment starts a single researcher directly. A normal
installation starts the kernel and has the operator arrange project teams.
That broader workflow has not been exercised here.

Native Codex uses workspace-write and on-request approvals. Network access is
enabled so it can call the local daemon. The agent's role limits this exercise
to local notes; the lab does not automatically grant permission to deploy or
launch additional agents. See `codex.toml` and `agent/role.md`.

## Give the researcher another small experiment

Save a concrete question, allowed actions, expected report path, and stopping
condition in a brief. Assign it using a new ID; reuse that same ID and identical
arguments if retrying an uncertain submission:

```sh
./experiments/openrig/lab queue create \
  --source john \
  --destination notes-researcher@notes-lab \
  --id my-next-notes-experiment \
  --summary 'Investigate one notes workflow and save the evidence.' \
  --body-file /absolute/path/to/brief.md \
  --verify --json
```

`--verify` reports persistence and delivery/claim observations; it does not wait
for the experiment to finish. Follow the queue record and read the resulting
file. A completed handoff is not the same as an accepted outcome.

Keep project outcomes in Beads and lab handoffs in OpenRig. This investigation
is tracked by `nixos-txy.2`; the notebook proposal is `nixos-txy`.

## Stop and return

To pause the agent with a snapshot, then restore it:

```sh
./experiments/openrig/lab down notes-lab --snapshot
./experiments/openrig/lab up notes-lab --existing
```

To stop the local daemon, first pause the lab, then run:

```sh
./experiments/openrig/lab daemon stop
```

Stopping only the daemon can leave tmux conversations alive. After restarting
the daemon with the same `--no-kernel --host 127.0.0.1 --port 17433` arguments,
inspect `ps` before launching or restoring anything. A daemon restart, a warm
conversation restore, a fresh conversation, and a host reboot are different
recovery cases.

## Reading

- [Getting started](https://openrig.dev/docs/getting-started): the normal kernel
  and project-team workflow.
- [Coordination](https://openrig.dev/docs/coordination): observations,
  classification, queues, and handoffs.
- [Context](https://openrig.dev/docs/context): context packs, sections, and
  handover information.
- [Context engineering](https://openrig.dev/blog/how-my-agent-teams-find-their-way):
  making prior knowledge discoverable and tracing conclusions to evidence.
- [Source architecture](https://github.com/mvschwarz/openrig/blob/v0.6.11/ARCHITECTURE.md):
  daemon, adapters, API, and supported interfaces.
- [Official Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference):
  native provider settings used by the lab.

Use the installed command's `--help` when an example and a command disagree.
