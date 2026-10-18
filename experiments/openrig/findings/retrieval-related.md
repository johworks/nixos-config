Export note: copied from the neutral fresh-conversation evaluation. Source-report links were adjusted for this directory.

# Investigation: remembering an idea and its uncertainty

Assignment: `notes-check-01-task`. Date: 2026-10-18 UTC.

## Original idea

“When I revisit an idea weeks later, I want the agent to remember what we tried and explain what is still uncertain.”

## Finding

Relevant prior evidence exists. Two local reports record an initial investigation and a directed reuse check. This investigation found both without a supplied note path and can use them to explain what was tried and what remains untested. That is a narrow discovery result in a workspace with only two research notes, not evidence of reliable recall weeks later.

## Search method

I checked live identity and my owned queue, read the complete assigned item with `rig queue show notes-check-01-task --full --json`, and claimed it. I listed workspace files with `rg --files --hidden -g '!.git' -g '!result.md'`; a second listing with `--no-ignore` returned the same three files: `AGENTS.md` and the two notes cited below. I searched local contents using `rg -n` with the terms `idea|revisit|remember|tried|uncertain|experiment|continuity|retriev`, excluding `.git`, the instructions, and this output. I then read both notes completely with `cat`.

I inspected only this workspace and my assigned queue item. I did not follow the notes' references to other rigs, queue items, context packs, transcripts, or original artifact paths. Their historical command results are reported evidence, not live checks performed in this investigation.

## Relevant evidence and what it supports

### [First OpenRig experiment](first-experiment.md)

This report, dated 2026-10-18, records the original idea `notes-lab-001`: capture a rough idea on a phone, investigate it in the background, and retain linked Markdown findings. It reports inspecting the original stream text, a separate classification linked by stream ID, an assigned queue item, and goal context. Intake and classification were parent-driven; the queue assignment was created separately. This supports preserving the original thought, interpretation, provenance, and findings as distinct linked records. It does not establish an autonomous pipeline.

The report explicitly leaves phone capture, autonomous execution, restart recovery, lease expiry, duplicate handling, and automatic finding discovery untested. Lease and idempotency protections were described in help, not exercised. Its proposed follow-up was a related idea leading to a second report that cites the first; that proposal is not evidence that the experiment occurred.

### [Continuity and directed note reuse](continuity.md)

This same-day follow-up reports reading the first report and checking its completed assignment and retained queue transitions. It supports a narrower historical observation: a saved report and an auditable work record were usable for directed reuse without repeating the stream/classifier investigation.

The report distinguishes the parent's testimony about stopping and restarting the daemon from its own checks. The earlier report path was explicitly supplied, and prior conversation was visible. Matching seat identity did not prove conversation restoration. It expressly does not establish autonomous discovery, cold-start discovery, reboot recovery, or a working notebook application. Its proposed next step was discovery from a related idea without an exact report path—the narrow test performed in this assignment.

## Observations versus assumptions

- **Observed here:** both relevant notes were discoverable through local file listing and text search without their paths in the assignment; both could be read in full and cited. Their text supports the account above. I did not repeat the historical tool investigation.
- **Recorded historical observations:** the first report describes explicit intake/classification/queue/context checks; the second describes directed reuse and completion-history checks. I have not independently verified those old system states.
- **Still assumptions:** the notes are complete enough to represent everything tried; the same retrieval method scales to a larger collection; later evidence will be found and supersede older conclusions; and an agent will preserve these distinctions after weeks away. None is demonstrated by this two-note, same-day evaluation.

## Remaining uncertainty

The requested elapsed-time behavior is untested: both source reports and this investigation are dated 2026-10-18. This assignment supplies fresh task context and a very small local corpus; it does not demonstrate an unsupervised revisit or automatic scheduling. There is also no local evidence of an implemented notebook, phone interface, or autonomous processing policy. The reports establish useful research continuity, not those product capabilities.

The central unanswered question is whether a later agent can select the relevant evidence amid unrelated or newer notes, explain what changed, and retain uncertainty without treating proposals or parent testimony as completed tests.

## Smallest useful next experiment — proposed, not executed

Retain this report with the two source notes and revisit the same idea in a fresh session after a real delay, with no note paths or prior conversation supplied. Use the ordinary local note collection available then. Have a human compare the resulting account against these cited records.

Success means the agent finds the relevant notes, identifies the parent-driven initial investigation and directed reuse check, recognizes this limited discovery test, and preserves the distinction between observed results, testimony, and unexecuted proposals. It should explicitly leave weeks-later reliability unproven if the delay was shorter than weeks. Record any missed evidence, false claim of a completed test, or proposed repetition of already established work.

This tests the remaining continuity question without rerunning the stream/classifier checks, rebuilding a notebook, or repeating the same two-note discovery exercise immediately. No experiment, application, additional task, or agent was started here.
