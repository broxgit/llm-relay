# How a piece of work goes

**Status: Brock adopted this flow on 2026-11-06. The relay's everyday skill teaches it to Cowork, as 0.2.10. That teaching has not been tried with real Cowork. Two commands the flow wants are not built.**

The relay had commands for parts of a job, and nothing that said how the parts fit. After a ticket, Cowork waited to be steered. This is the order work goes in, so Cowork knows where it is and what comes next.

It began as Brock's usual way of working with an assistant. The steps marked *added* came from reviewing that flow as an engineer, and he accepted them. One addition is his own: dependencies are read in both directions.

## The flow

### 1. Research

1. The ticket.
2. Associated tickets.
3. Associated Confluence pages: ADRs, RFCs, design docs, PRDs.
4. Figma designs.
5. The codebases that will change.
6. *Added:* what depends on them, and what they depend on. Other services and libraries, API and schema compatibility, rate limits, migrations.
7. *Added:* a baseline. The build and the tests are run before anything is touched. For a bug, it is reproduced first.
8. *Added:* the open questions, each with who can answer it, in product, design or another team. They go out early, so answers arrive while the plan is made.

### 2. Plan

1. A plan made together, with questions both ways.
2. *Added:* what "done" means. What must be true at the end, and how each thing will be shown. These become the test scenarios.
3. *Added:* the slices. One merge request or several, and in what order.
4. *Added:* the rollout. Deploy order across services, config changes, how to roll back, and what to watch afterwards.
5. The plan is written down, in a markdown file or a Confluence page.
6. Whether an ADR, RFC or design doc is needed.
7. *Added:* nothing starts that waits on an unanswered question.

### 3. Implement

1. The person proposes what code goes where. The assistant looks for gaps, concerns and risks.
2. They write it together. Either may lay the scaffolding.
3. *Added:* commits as you go, in small steps that each build.

### 4. Test

1. *Changed:* the test plan starts from the "done" list, and adds scenarios that only became clear while building.
2. Which are unit tests and which are integration tests.
3. The assistant writes them.
4. *Added:* everything is run against the baseline. A new failure belongs to this change.

### 5. Review before pushing

1. A fresh session reviews the code.
2. *Added:* a second pass against the plan. Does it do what was agreed, and is everything on the "done" list shown?
3. *Added:* the person reads the whole diff themselves.

### 6. Commit, push, create the merge request

1. *Added:* the "done" list and the rollout notes go in its description.

### 7. The merge request's comments

### 8. After the merge

*Added, all of it.*

1. Verify in staging, then production, against the "done" list.
2. Watch what the plan said to watch.
3. Update the ticket, the plan and the wiki with what happened and why.

## Why the additions

- **"Done" before code.** With the test plan made after the code, tests tend to confirm what the code does, and not what the ticket asked for.
- **A baseline.** Without one, a failure found later could be new or could have been there all along, and a bug fix can't show it fixed the bug.
- **After the merge.** Much of what goes wrong is there: the order services ship in, config in another repository, whether it works in staging. A real review on 2026-11-06 found that one service had to ship before another, and found it at review, where it cost more than it would have in the plan.
- **Questions with owners.** Research turns up things only a person can answer. Without a step for them, work gets built on a guess.
- **Both directions of dependency.** What calls the code being changed can break. What that code calls sets its limits.

For a small ticket, three of the additions are worth keeping whatever else is dropped: the baseline, the "done" list, and reading your own diff.

## The flow and the relay

| Stage | With Cowork | What's missing |
|---|---|---|
| 1. Research | `relay ticket`, with `--page` for Confluence. `relay scan` for each repository, with its wiki. A first `relay run` that changes nothing is the baseline | Linked tickets come as a key, a title and a status. Figma has no route |
| 2. Plan | Conversation, with the skill saying what a plan holds | The plan stays in Cowork. Nothing saves it to the Mac |
| 3. Implement | The person's edits go up with the next `relay scan`. Cowork's come down through `relay run` and `relay apply` | Each exchange costs minutes, so it isn't pairing |
| 4. Test | `relay run`, which is what the relay is best at | Nothing |
| 5. Review | A new Cowork session, a scan, and the plan's "done" list | No command packs a branch for review before a merge request exists |
| 6. Merge request | The person's. Cowork drafts the description | Nothing. The relay never commits or pushes, on purpose |
| 7. Comments | `relay mr` | Nothing |
| 8. After the merge | Cowork gives the checklist and drafts the ticket update | Cowork can't see staging or production |

## What the skill tells Cowork

`remote-pair-run` has a section, "How a piece of work goes", with the stages, what Cowork does in each, and what the user runs. Three rules sit above the stages:

- **Say which stage you're in when it changes.**
- **Don't skip ahead.** The usual mistake is code before the plan is agreed.
- **The user can cut it down.** For a small change, ask which stages they want.

## Not built

- **A review of a branch before a merge request exists.** Stage 5 has no command. It would be `relay mr` without GitLab: the branch against its target, the checks, the user's review skill and the wiki.
- **The plan as a file on the Mac.** `relay review` already saves a file Cowork wrote, after a keypress. The same route could carry a plan.
- **Linked tickets fetched with the ticket,** and **a repository's wiki sent with a ticket.**

## Not known

- Whether Cowork keeps to the stages, or goes straight to code when a ticket looks simple.
- Whether saying the stage aloud helps the user or gets in the way.
- How the flow feels at stage 3, where each exchange with Cowork is slow.
