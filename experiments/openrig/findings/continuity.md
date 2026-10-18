# Continuity and directed note reuse

Date: 2026-10-18 UTC. Assignment: `notes-lab-continuity`.
Previous finding: [First OpenRig experiment](first-experiment.md).
Original idea: `notes-lab-001`, capturing a rough idea on a phone, investigating
it in the background, and retaining linked Markdown findings.

## Method and evidence

I read `rig queue show notes-lab-continuity --full --json` and claimed it with
`rig queue claim notes-lab-continuity --json`. The claim returned `in-progress`
at `2026-10-18T14:04:04.564Z`.

The brief reports that the parent took a snapshot, stopped and restarted the
daemon, restored the existing rig, and received a `resumed` result. Those actions
are parent testimony; I did not perform or independently inspect them.
Earlier conversation is visible in my supplied context. I checked durable
evidence rather than relying solely on that conversation:

- `rig whoami --json` returned rig `notes-lab`, pod `notes`, logical ID
  `notes.researcher`, session `notes-researcher@notes-lab`, runtime `codex`, and
  node ID `01M57MY3G2TZ0N0FCAPXNT72QW`, matching the earlier identity result.
- `cat findings/first-experiment.md` returned the complete earlier report,
  including its observations, parent-driven provenance, and limitations.
- `rig queue show notes-lab-first-report --full --json` returned `done` with
  closure reason `no-follow-on`.
- `rig queue transitions notes-lab-first-report --json` retained creation,
  claim, and closure. Transition 3, dated `14:01:26.886Z`, links the first report.
- `rig context get notes-lab/notes.md#goal` again returned John's goal of phone
  and desktop capture, agent categorization and exploration, and linked findings.

These checks succeeded. I did not repeat the stream/classifier investigation.

## Two observations to carry forward

1. **Preserve the thought separately from its interpretation.** The first report
   records original text under stream ID `notes-lab-001` and a separate
   classification linked by that ID. Intake and classification were initially
   driven by the parent session. A future notebook experiment should retain
   that provenance so a label does not replace the original idea.
2. **A report plus an auditable work record supports directed reuse.** The first
   report linked stream, classification, assignment, and context evidence. This
   follow-up could read the saved report and verify its completion against the
   retained queue history. A future experiment can build on a cited finding
   instead of repeating its investigation; the goal context remains available
   to keep that work relevant.

## What this does not establish

We still cannot claim autonomous retrieval of relevant prior findings. This was
a warm-restore check with an explicitly supplied report path and visible prior
conversation. It does not demonstrate cold-start discovery, reboot recovery,
or a working notebook application. The matching seat identity alone does not
prove native conversation restoration or reveal how restoration worked.

## Next useful step

If separately assigned, test finding discovery with a related idea and no exact
report path in its brief, then check whether the resulting report cites relevant
prior evidence. That is a proposal, not work started here.
