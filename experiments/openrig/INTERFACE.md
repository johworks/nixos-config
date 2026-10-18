# How to talk to OpenRig

Your point of contact is an agent's conversation. In this lab that is
`notes-researcher@notes-lab`. A rig is the saved team setup; a seat is a named
role within it; an agent conversation occupies that seat. You do not need to
address every member of a team to give the team a goal.

## Talk directly

From the repository root:

```sh
./experiments/openrig/lab exec tmux attach -t notes-researcher@notes-lab
```

Type ordinary instructions in that Codex conversation. For example:

> Explain what our notes experiments established, what remains uncertain, and
> the smallest useful next experiment. Do not change anything yet.

Detach with **Ctrl-b, then d**. Detaching leaves the conversation running.
The lab researcher is restricted to bounded local investigations. It does not
have a team to delegate to, and its role forbids new installations, publishing,
and launching more agents.

## Send a message without joining its terminal

```sh
./experiments/openrig/lab send notes-researcher@notes-lab \
  'John: Explain the most important remaining uncertainty in our notes experiments. Do not start new work.'
./experiments/openrig/lab capture notes-researcher@notes-lab --lines 50
```

The answer appears in the agent's conversation. `capture` reads its current
screen; it does not wait for an answer. You can also attach to read and reply.
If the CLI reports that rendering is unconfirmed, inspect the conversation
before resending; the agent may already have received and answered it.

Our outside shell has no managed agent identity, so sign the message in its body.
In the live check, OpenRig delivered the message with an unknown-sender warning;
the researcher answered, and no queue item was created.

## Assign work that should be tracked

A conversation message and a queue assignment serve different purposes. This
lab does not automatically turn chat messages into tracked work. For a bounded
investigation, save a brief containing the question, allowed sources, expected
report, and stopping point, then submit it:

```sh
./experiments/openrig/lab queue create \
  --source john \
  --destination notes-researcher@notes-lab \
  --id my-notes-investigation-001 \
  --summary 'Investigate one idea and save the findings.' \
  --body-file /absolute/path/to/brief.md \
  --verify --json
```

Use a new ID for new work. For an uncertain retry, keep the same ID and identical
arguments. Follow progress with:

```sh
./experiments/openrig/lab queue show my-notes-investigation-001 --full --json
./experiments/openrig/lab capture notes-researcher@notes-lab --lines 50
```

`--verify` checks persistence/delivery observations, not experiment completion.
Read the report referenced by the completed queue item. You can also ask the
parent Codex conversation to submit and follow an assignment for you; this chat
is not automatically connected to the rig's intake stream.

## Observe the team

```sh
./experiments/openrig/lab tui
```

The dashboard shows topology, work, and status. Conversation happens in agent
terminals. In a normal OpenRig installation, the kernel operator helps arrange
teams; then you talk to the selected team's lead, which can clarify intent and
assign work to specialists. Our lab deliberately has the kernel disabled and
one researcher, so that larger-team workflow remains untested here.

`rig send --rig <name>` sends the same message to the rig's seats. It does not
choose a lead or divide the work. For a team goal, address its lead rather than
broadcasting the assignment to everyone.

## Capture a thought for later

`rig stream emit` stores an observation. In our current lab, saving a stream item
alone does not activate the researcher or create an experiment. A configured
consumer/classifier and routing workflow must connect capture to owned work.
That is a separate behavior from the working queue-delivery path above.

See [the controlled checks](findings/discovery-tests.md) and the
[learning walkthrough](README.md). Upstream references:
[messaging](https://openrig.dev/docs/messaging) and
[bringing feedback to a lead](https://openrig.dev/tour/feedback).
