# Read-only team coordination check

This is a setup check under the parent session's claimed Beads task
`nixos-txy.4`. It does not authorize wallpaper implementation, new project
Beads, source edits, commits, package installation, activation, or publishing.
Keep the repo unchanged except for OpenRig's own managed startup material.

Lead: claim this assignment and keep it open while the specialists work.
Create one durable assignment for `dev-builder@weather-wallpaper`, asking it
to run the existing `node --test wallpapers/cellular/life.test.cjs` checks and
report what happened. Ask it to hand the result to the reviewer, not to start
implementing anything. Queue delivery already nudges the destination.

Builder: claim your assignment, run only that existing test command, and hand
the result to `dev-reviewer@weather-wallpaper`. Include the actual test summary
and this check's constraints. Do not make repository edits or create Beads.

Reviewer: claim the handoff, inspect the builder's result, read the existing
wallpaper README, and check for source diffs under `wallpapers/cellular/` and
`hosts/desktop/cellular-wallpaper.nix`. Do not rerun the test without a reason.
Hand a short verdict to the lead, explicitly identifying it as this setup
check's result, with the original lead assignment ID. Make no source edits.

Lead: read and claim the returned result, close that return item, then close
your original assignment with the evidence and the downstream queue IDs.
Tell John how to discuss a wallpaper goal with you and that the team is ready.
Then wait for his actual goal. Do not create more work or start the prototype.
