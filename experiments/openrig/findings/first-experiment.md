# First OpenRig experiment

Date: 2026-10-18 UTC. Owner: `notes-researcher@notes-lab`.
Assignment: `notes-lab-first-report`. Original stream item: `notes-lab-001`.

## Original idea and question

The original stream text is: “Capture a rough idea on my phone, investigate it
in the background, and keep linked Markdown findings for the next experiment.”
The broader goal includes phone and desktop capture, categorization, related
ideas, and eventual implementation tasks linked back to evidence.

Question: does the installed OpenRig provide an execution and context
foundation for that notebook? The current decision is to learn the tool first;
this experiment does not implement a notebook application.

## Method and evidence

I read the complete assignment with
`rig queue show notes-lab-first-report --full --json`, then claimed it with
`rig queue claim notes-lab-first-report --json`. The claim returned
`in-progress`, attributed to this seat at `2026-10-18T14:00:04.771Z`.
`rg --files` listed only `AGENTS.md`; no earlier findings were listed.

I inspected installed help for `rig stream`, `rig project`, `rig queue`, and
`rig context`, including `project classify`, `project wake`, `project candidates`,
`queue update`, and `context get`. Read-only checks returned:

| Surface and actual command | Observed result |
| --- | --- |
| `rig stream show notes-lab-001 --json` | Original text preserved, source `john`, emitted `13:57:59.646Z`, hint type `idea`, tags `notes` and `experiments`, unarchived. Help describes an append-only intake stream. |
| `rig project list --destination notes-researcher@notes-lab --json` | One classification for that stream ID: type `idea`, urgency `normal`, maturity `concept`, confidence `high`, area `notes`, action `create`, destination this seat, `needsHuman=false`. |
| `rig project show 01M57MY33X61N60Q1VKN334N69 --json` | Confirmed the classification, timestamp `13:59:03.037Z`, classifier session `classifier@notes-lab`, classifier version `manual-lab-v1`, taxonomy `notes-v1`. |
| `rig project lease-show --json` | At inspection, an active classifier lease expiring at `14:13:49.857Z`. This is a lease record, not proof of a running classifier agent. |
| `rig queue transitions notes-lab-first-report --json` | Creation by `john` followed by my claim. The assignment carries `idea:notes-lab-001` and `bead:nixos-txy.2` tags. |
| `rig context get notes-lab/notes.md#goal` | Returned only the Goal section. Separate reads of `#current-decision` and `#knowledge` also succeeded. |
| `rig context show notes-lab --json` | User-authored context pack version `1`, containing `notes.md`. |

**Intake and classification were initially driven by the parent session.**
This was not autonomous idea processing. The classification label's `high`
confidence is stored metadata, not an independently verified assessment.

## How the surfaces fit

The stream preserves the original thought; the project classification adds an
interpretation and destination linked by stream ID. The queue assigns bounded
work to a seat and records claim and closure history. Context supplies the goal,
decisions, and knowledge rules for that work. This report supplies the local
finding that the queue closure can reference.

That is a useful foundation, demonstrated here through explicit commands.
It does not establish automatic stream-to-queue routing: the assignment was
created separately, and its idea tag supplies the observed link.

The installed `project classify --help` documents a required active lease and
idempotency on stream ID; these protections were not exercised. `project wake`
help describes a bounded wake with authored taxonomy and source-bound decisions;
I did not run it. Installed context guidance says context stores/composes content
and delivery verbs deliver it; retrieval alone does not schedule work.

## Wiring still needed and limits

The notebook still needs a capture interface, authored classification taxonomy
and decisions, a defined trigger for processing, and a verified policy for
turning classifications into queue work. Linking related ideas, retrieving prior
findings, and promoting implementation work also need authored conventions and
verification. None is established by this one example.

I did not test phone capture, autonomous execution, restart recovery, lease
expiry, duplicate handling, or automatic finding discovery. No app, configuration,
additional queue item, agent, or external integration was created.

One helper failed: `rig context list --json | python3 -c '…'` exited `127`
because `python3` was unavailable. No software was installed. Broad context
listing and `openrig-user` reads exceeded output limits; focused reads and help
were used for the claims above, without assuming truncated material was read.

Relevant context: `notes-lab/notes.md#goal`, `#current-decision`, `#knowledge`;
`openrig-user`, especially “Context packs and paced delivery (0.5.0)”;
`queue-handoff`, which documents `no-follow-on` completion. Retrieve these with
`rig context get <ref>`.

## Smallest next experiment (proposed, not executed)

Have the parent assign one additional bounded experiment: submit one new idea
related to `notes-lab-001`, explicitly classify and route it, and ask the same
researcher to find this report and write a linked follow-up. Success would be a
traceable original stream ID, classification, queue item, and second report
citing this finding. Label each parent-driven step honestly. This tests useful
knowledge reuse before introducing autonomous scheduling or a frontend.

## Verification

Read back the saved report with `cat findings/first-experiment.md` and checked
its sections, original idea reference, parent-session attribution, recorded
failure, and proposed next experiment with `rg -n`. All required content was
present. After closure, `rig queue show notes-lab-first-report --json` and
`rig queue transitions notes-lab-first-report --json` confirmed `done` with
`no-follow-on` and this report's path in transition 3. The owned queue returned
`[]`. These document checks do not establish notebook application behavior.
