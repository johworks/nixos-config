# Fresh-conversation discovery and input checks

Date: 18 October 2026. Parent task: `nixos-txy.3`.

## Questions and results

| Question | Observed result |
| --- | --- |
| Can a fresh conversation find relevant findings without filenames? | Yes, in this two-note corpus. It listed and searched local files, read both reports, cited them, and preserved their limitations. |
| Will an unrelated idea cause invented connections? | No invented technical connection in this example. The reader explicitly found no wallpaper/weather evidence in the supplied notes and proposed an untested next experiment. |
| Does saving an idea alone start background research? | Not in the current lab configuration during the observation window. The stream item remained saved, with no classification or automatically created assignment. |
| Can John send ordinary instructions to the current agent? | Yes. A direct CLI message reached its conversation and it answered. The message created no queue item. |

The first two checks used explicitly assigned work. Their success does not
establish an automatic capture-to-research service. Useful work currently starts
when we assign it; raw intake has no configured consumer/routing workflow.

## Controlled retrieval setup

Two new one-seat rigs used the same model (`gpt-6.1-sol`), role instructions,
and copies of these two previously saved reports:

| Source | SHA-256 of supplied file |
| --- | --- |
| [First experiment](first-experiment.md) | `15c90fbc6e0952a8b6fdcc12163fc332993669aa1d4c38052e53a58cbbc53898` |
| [Continuity](continuity.md) | `523ffc5e755f999d2782013b5388fa4830ce7cc9490912110351e4f2f38004fe` |

Each had a separate workspace containing those two notes under `library/` and
its own startup instructions. Neither could use the other workspace, shared
context packs, old session history, or other queue records. No expected verdict
was included in the agent's role or assignment. This is an instruction-bound
read scope, not an OS-enforced read-only container.

Native startup also includes ordinary repository guidance. The unrelated
reader noted its generic reference to wallpaper assets and correctly refused
to treat that as evidence of an existing weather integration.

The rigs were newly imported and launched, rather than resumed or forked from
the earlier researcher. Rigs, directories, and assignment tags used neutral
identifiers (`notes-check-01`, `notes-check-02`, and `evaluation:discovery`). An
initial pass used revealing case names and was excluded from the conclusions;
the neutral rerun supplies the final reports below.

Native session metadata showed distinct IDs:

- Related: `01a14f6e-fcab-7a92-bbbd-ef45c36b5252`, created 14:33:56 UTC.
- Unrelated: `01a14f6f-01aa-7993-bb79-6402335f6973`, created 14:33:57 UTC.

Their assignment template differed only in the idea:

> Investigate this idea using any relevant knowledge already available in your
> workspace. Find the relevant notes yourself; no note filenames or paths are
> supplied. If there is no relevant prior evidence, say so. Cite the files you
> actually read and explain what each supports. Distinguish past observations
> from untested assumptions. Suggest the smallest useful next experiment and
> avoid repeating established work unnecessarily.

The rest of the brief required a local report, an owned queue claim/closure,
and no implementation, browsing, new tasks, or additional agents.

### Related idea

“When I revisit an idea weeks later, I want the agent to remember what we tried
and explain what is still uncertain.”

Assignment `notes-check-01-task` was claimed at 14:34:26.938 UTC and completed
at 14:35:24.171 UTC. The
[full report](retrieval-related.md) cites both
notes, retains the parent-driven provenance of earlier classification, and
states that elapsed weeks, large-corpus selection, and automatic processing
remain untested. Its proposed next experiment concerns later retrieval rather
than rebuilding the stream or repeating the restore test.

The native tool trace confirms local `rg --files`, text search, and `cat` of
both notes. It shows no shared-context or historical-session retrieval.

### Unrelated idea

“Could my wallpaper react to the weather?”

Assignment `notes-check-02-task` was claimed at 14:34:25.628 UTC and completed
at 14:35:09.112 UTC. The
[full report](retrieval-unrelated.md) explains
that the two notes supply research-process precedent, with no technical
evidence about wallpaper or weather. It proposes a manual two-condition trial
and labels it unexecuted. It correctly limits the absence claim to this corpus;
the parent repository and John's wider work were outside its read scope.

The trace confirms a local inventory, weather/wallpaper text search, and full
reads of the two notes. Both assignments closed with
`no-follow-on` and report paths. Both evaluation rigs were then stopped with
snapshots and archived to keep the default dashboard focused on the original
lab. Their records remain retained; the original researcher was left running.

## Stream-only background check

At 14:27:14.462 UTC, the parent emitted `notes-stream-only-20261018` with the
related idea, hint type `idea`, and tags `notes,retrieval,synthetic`. It supplied
no destination, no interrupt flag, and no assignment for that stream item.

After at least three minutes, inspection showed:

- The original stream row remained available and unarchived.
- `rig project list --json` still contained only the earlier manually supplied
  classification for `notes-lab-001`.
- The full cross-rig queue had four rows: the two earlier assignments and the
  two initial explicitly created evaluation assignments. No stream-originated row was
  added; all four existing assignments were done.
- `rig workflow list --json` returned no instances. Watchdogs listed digest and
  parked-owner jobs, not an intake classifier for this idea.

The same paraphrased idea was separately assigned to the related evaluation;
that explicit assignment is not evidence of stream-driven work. The original
researcher also received a conversational interface question during the window,
with an instruction not to inspect the new stream item. The daemon was running
throughout. The result describes this configuration and window; it does not
assert that OpenRig cannot be configured to process intake automatically.

## Conversation input check

The parent sent the existing researcher a bounded explanatory question using
`lab send ... --wait-for-idle 15 --verify --json`. The CLI reported delivery
with rendering unconfirmed and an unknown-sender warning because the outside
shell had no managed agent identity. A later capture showed the exact question
and the researcher's answer. The queue still contained only its two earlier
completed assignments.

The researcher explained that John can type in its terminal or use `rig send`,
and that a message alone does not create a durable queue obligation. Sign
outside-shell messages in their body; `--verify` is a delivery observation, not
an experiment-completion check.

See [How to talk to OpenRig](../INTERFACE.md) for the practical interface.

## What to test next

This is one positive and one negative example against two notes, with an
explicit request to search existing knowledge. It does not measure spontaneous
retrieval, accuracy at scale, stale/conflicting evidence, actual weeks of
elapsed time, or integration with a capture frontend. The next useful check is
a real idea whose returned synthesis John can judge, followed by a configured
capture-to-assignment experiment if that synthesis is useful.
