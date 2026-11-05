# Design and decisions

Where the relay goes next, and the decisions behind it. Written 2026-11-05, against commit 6541e46. Each file says at the top what is adopted and what is still a proposal.

| File | What it holds |
|---|---|
| [design.md](design.md) | How the relay works today, two proposed designs, and the alternatives that were dropped. |
| [roadmap.md](roadmap.md) | Three phases in order, what each needs, and the decisions waiting on Brock. |
| [work-mac-session.md](work-mac-session.md) | Exact steps for one session with real Cowork and OneDrive, and what to bring back. |
| [leverage.md](leverage.md) | What Claude is used for at work, and nine steps for moving more of it to Cowork. |

In short: close a way round the keypress gate (built, on the `keypress-gate` branch), prove the standalone relay on the work Mac, then wake Cowork without typing "done". After that, [leverage.md](leverage.md). The relay stays in Bash, OneDrive stays the only channel, and nothing is added that runs without a keypress on the Mac.

When a proposal is adopted, record the decision in [roadmap.md](roadmap.md) with its date, and move the phase into the repository's [ROADMAP.md](../ROADMAP.md).
