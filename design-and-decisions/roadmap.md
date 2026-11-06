# Proposed roadmap

**Status: phase 1 is done, merged on 2026-11-05 as [pull request 1](https://github.com/broxgit/llm-relay/pull/1). Phase 2 ran on 2026-11-06, as the guided field test, and its fixes are release 0.2.2. Phase 3 can't be built as designed: the user's Teams had no Workflows app, so there is no webhook. [Team use](#team-use) was added on 2026-11-06, and nothing in it is built.** The repository's [ROADMAP.md](../ROADMAP.md) stays the record of what's done and untested. [leverage.md](leverage.md) has what comes after these three.

Three phases in this order, with one condition: the wake-up is built only if the work-Mac session shows Teams and Cowork allow it. No dates, because the pace is about 10 hours a week and two phases wait on time at the work Mac. [design.md](design.md) has the designs behind phases 1 and 3.

```mermaid
flowchart LR
    P1["1. The gate holds<br/>Done 2026-11-05"] --> P2["2. A real run<br/>Work Mac, about an hour and a half"]
    P2 --> G{"Teams allows the webhook,<br/>and a Cowork trigger fires on it?"}
    G -- yes --> P3["3. Wake-up<br/>Built here, tried at work"]
    G -- no --> S["Typing done stays"]
```

| Phase | Where it happens | Needs from Brock | Done when |
|---|---|---|---|
| 1. The gate holds (done) | The personal Mac, no Cowork | A yes to Design 1, and a call on `--checks`. Both given | No pipe or variable answers the prompt. Tests answer through a pseudo-terminal. CI is green on Linux and macOS. `AGENTS.md`, `README.md` and `docs/using.md` say what the gate does and doesn't stop |
| 2. A real run | Work Mac, about an hour and a half | [The session](work-mac-session.md), and what it asks to bring back | Every item on `ROADMAP.md`'s Untested list is crossed off or has a recorded failure. The wake-up questions have answers |
| 3. Wake-up | Built on the personal Mac, then about 30 minutes on the work Mac | The answers from phase 2, then one more short session | A round finishes on the work Mac without typing "done", and a failed post falls back to today's message |

Phase 1 goes first so the real run exercises the final prompt. If phase 2 turns up a failure in something already built, fixing it comes before phase 3.

## Team use

Added on 2026-11-06. The relay was built for one person who knows it well. It is now meant for the developers on Brock's team too, of varying skill levels, and they shouldn't need to know its commands or its unwritten rules.

Three pieces, in this order. They come after phase 2's report is read and its failures are fixed, and before phase 3 and the steps of [leverage.md](leverage.md) that aren't built. [guided.md](guided.md) has the design. A and B are built, as 0.2.5. Of C, the starting question and the short block are built, and the practice round is not. None of it has run with real Cowork.

| # | Piece | What it does | Waits on |
|---|---|---|---|
| A | Say which tools a feature needs | `relay setup` lists each feature's tools and whether this Mac has them. A missing tool's error gives the install line and the sign-in step. One list in the code feeds every message, so a new dependency is one line | Nothing from Cowork. It can be built and tested on the personal Mac |
| B | The guided way in, in the terminal | `relay start` is the one command to learn. It checks the install, catches a stale skill after an upgrade, and puts a prompt for Cowork on the clipboard. Every command ends with a line saying what to do next, and `relay scan` gets a clipboard prompt as `relay mr` has | Nothing from Cowork, as for A |
| C | The guided way in, in Cowork | The everyday skill hands over each command in a short YOUR TURN block. Cowork asks what the user is working on and picks the first command. A practice round runs on the field test's throwaway repository | Phase 2's report, which says whether Cowork keeps to the block format |

What holds across all three:

- **Guidance goes in the terminal where it can.** The relay prints the same thing every time and can be tested without Cowork. Cowork has needed a second ask for steps it was told to give.
- **Tools stay optional.** Someone who never reviews a merge request isn't made to install `glab`. `relay setup` reports and doesn't refuse.
- **The keypress rule doesn't change.** The guide says which key and why. It never presses it.
- **The commands stay.** `relay scan` and `relay mr` work as they do now for anyone who knows them.

Today a user learns that `relay mr` needs `glab` when a review fails with `relay mr needs glab`, and the YOUR TURN block is only in the field-test skill.

## Parked

With no phase yet:

- Comparing a Cowork review with a Claude review of the same merge request.
- Sending the Go toolchain with a scan.
- Letting Cowork leave notes for the wiki through `wiki capture`.

## Decisions needed

The first two are answered, and phase 1 was built on them. The rest can wait until phase 2 is back. When one is made, write the answer and its date under it.

- [x] **Design 1 as written:** the prompt reads `/dev/tty`, `RELAY_TEST_TTY` goes, and the tests use a pseudo-terminal. Brock said to get started on 2026-11-05.
- [x] **`relay mr --checks`:** keep it as the one named exception to the keypress rule. Brock decided on 2026-11-05. Phase 1 was built that way, with the skill told never to hand the flag over.
- [ ] **The webhook address:** whether an address for a Teams chat, kept in a settings file on the work Mac, is acceptable under the company's rules. Phase 3 depends on it.
- [ ] **The MCP bridge:** drop it from `ROADMAP.md`, where it stands as the step after the wake-up.
- [ ] **The Go binary test:** drop the test of a Go binary in the skill folder.
- [ ] **The Jira tool:** `jira` or `acli`, for `relay ticket`. It waits on phase 2's report, which says whether Cowork can read Jira itself.

## Decided

- 2026-11-05: these proposals live in this folder.
- 2026-11-05: start phase 1. It merged the same day, as [pull request 1](https://github.com/broxgit/llm-relay/pull/1).
- 2026-11-05: lean on Cowork far more at work, in the order in [leverage.md](leverage.md).
- 2026-11-05: `relay mr --checks` stays, as the one exception to the keypress rule.
- 2026-11-06: the relay is for Brock's team too, so each feature gets guided. The team-use pieces wait for phase 2's report.
- 2026-11-06: a feature that depends on a tool tells the user so. Depending on a Jira command-line tool is fine.
- 2026-11-06: design and build the guided way in. [guided.md](guided.md) has what was built and why.
- 2026-11-06: phase 2's report came back. The repository's [ROADMAP.md](../ROADMAP.md) has what passed, what 0.2.2 fixed, and what is still open. Three of its answers bear on what comes next: Cowork can't read Jira or Confluence and the Mac has `jira` and `acli`, a Go module with vendored dependencies builds in Cowork's sandbox, and Teams offered no way to make a webhook.
