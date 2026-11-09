# Design and decisions

Where the relay goes next, and the decisions behind it. Written 2026-11-05, against commit 6541e46. Each file says at the top what is adopted and what is still a proposal.

| File | What it holds |
|---|---|
| [design.md](design.md) | How the relay works today, two proposed designs, and the alternatives that were dropped. |
| [roadmap.md](roadmap.md) | Three phases in order, what each needs, and the decisions waiting on Brock. |
| [work-mac-session.md](work-mac-session.md) | A walk through testing everything that is built, with real Cowork and OneDrive: what to run, what to expect, prompts to paste into Cowork, and what to bring back. |
| [attempts.md](attempts.md) | Several ways of fixing something in one run, tried in order. Built. |
| [skill-sync.md](skill-sync.md) | How your own Claude skills reach Cowork, adapted, and how the copies stay in step. Built. |
| [guided.md](guided.md) | One command to begin with, for a team that doesn't know the relay: `relay start`, the list of what each thing needs, and how Cowork gives a step. Built, apart from the practice round. |
| [flow.md](flow.md) | The order a piece of work goes in, from the ticket to after the merge, what the relay does at each stage, and what's missing. Adopted, and taught to Cowork by the skill. |
| [leverage.md](leverage.md) | What Claude is used for at work, and nine steps for moving more of it to Cowork. |
| [ask.md](ask.md) | Waking Cowork from the Mac with a webhook, and `relay ask` built on it. A proposal, with the test to run first. |

In short: close a way round the keypress gate (done, merged on 2026-11-05), prove the standalone relay on the work Mac, then wake Cowork without typing "done". After that, [leverage.md](leverage.md). The relay stays in Bash, OneDrive stays the only channel, and nothing is added that runs without a keypress on the Mac.

When a proposal is adopted, record the decision in [roadmap.md](roadmap.md) with its date, and move the phase into the repository's [ROADMAP.md](../ROADMAP.md).
