# Leaning on Cowork

**Status: direction adopted on 2026-11-05. The order below is agreed. Steps 2, 3 and 5 are built, and the other six have no design yet.**

The three phases in [roadmap.md](roadmap.md) make the relay safe and proven. This is what it's for after that: moving as much of Brock's daily work as possible to Copilot Cowork, where the tokens are, without weakening the keypress rule or going round what the work tenant allows.

The idea behind all of it: today Cowork writes code blind and waits for the Mac, so every iteration costs a keypress. Give Cowork enough to work alone, and keep the Mac for the final proof.

## What Claude is used for at work

Brock's top 15 uses, from about 2,600 prompts in 72 saved Claude Code sessions at work. The counts behind the ranking are keyword matches, so trust the top of the list more than the bottom.

| # | Use | Fit for Cowork | What it takes |
|---|---|---|---|
| 1 | Reviewing other people's merge requests (about 200 prompts) | Works once proven | `relay mr` and `relay review` exist |
| 2 | Working through review comments on his own merge requests | Works once proven | The same commands, plus `relay apply` |
| 3 | Starting work from a Jira ticket | Needs a new pack | `relay ticket` |
| 4 | Getting up to speed on unfamiliar code | Reading only | `relay scan`, then `relay ask` |
| 5 | Writing QA and developer test instructions | Needs a build | His skill in Cowork, and dependencies in the sandbox |
| 6 | Writing new Go code, tests and tools | Needs a build | Dependencies in the sandbox |
| 7 | Upgrading dependencies and major versions | Needs a build | Dependencies in the sandbox, and deliverables with branches |
| 8 | Fixing failing tests, builds and pipelines | Needs a build | The same |
| 9 | Git work and merge conflicts | Stays with Claude | It needs his checkout |
| 10 | Production and observability | Stays with Claude | It needs live credentials |
| 11 | Data queries and analysis | Reading only | Nothing new: Claude already writes the script and he runs it |
| 12 | Drafting replies to coworkers | Reading only | His plain-English skill in Cowork, which already sees Teams and email |
| 13 | Status updates and standups | Reading only | Git history and wiki pages sent by the Mac |
| 14 | Design documents and meeting notes | Reading only | Cowork already sees the transcripts and SharePoint |
| 15 | Building Claude's own skills and the wiki | Stays with Claude | It is about Claude itself |

About ten of the fifteen can move mostly to Cowork.

The rules he repeats across all of them: no posting to GitLab, Slack or Jira without approval, no running database scripts, a plain human voice, and reading the real code and logs before answering. Cowork has no network, so it can't post anywhere or run a database script. Its sandbox enforces the first two.

## The order

Ordered by how much of that work each step moves, and by what depends on what.

| # | Step | Serves uses | Notes |
|---|---|---|---|
| 1 | Prove reviews on the work Mac | 1, 2 | Phase 2 of [roadmap.md](roadmap.md) |
| 2 | Sync his Claude skills to Cowork | 1, 5, 12 | Built on 2026-11-05, as `relay setup --skills`. Not yet tried with Cowork |
| 3 | Use what only Cowork sees | 12, 14, and context for 1 and 3 | Built on 2026-11-05, as text in the skill. Not yet tried with Cowork |
| 4 | Toolchain and dependencies in the sandbox | 5 to 8 | The biggest unknown. Needs a short test on the work Mac first |
| 5 | Deliverables with branches | 7, 8 | Built on 2026-11-05, as attempts. One keypress buys several iterations. Not yet tried with Cowork |
| 6 | `relay ticket` | 3 | Built on 2026-11-06, with `acli`. The Mac fetches the Jira ticket and the Confluence pages the user names. Not yet tried with real Cowork. A ticket's GitLab history isn't in it |
| 7 | `relay ask` | 4 | Cowork as the cheap sub-agent for Claude. Built at 0.2.15 |
| 8 | Cowork drafts wiki pages | 4, 13 | Returned the same way as an answer from `relay ask` |
| 9 | Overnight reviews | 1 | Last, because sending code to OneDrive unattended is a policy decision |

Steps 2 and 3 are small and land together. So do 4 and 5.

## The steps

### 1. Prove reviews on the work Mac

Reviews are the largest use, and the commands exist. They have run once on a real merge request, before the checks and the Coverage section were added. [work-mac-session.md](work-mac-session.md) part D is the proof.

### 2. Sync his Claude skills to Cowork

Cowork finds skills at `Documents/Cowork/skills/<name>/SKILL.md`, the same shape Claude uses, with up to 50 skills of 1 MB each. `relay setup --skills` copies the ones he names, such as his review, test-instruction, plain-English and alerting skills. Each copy carries a note saying what to do differently in Cowork, and is kept in step with his skill. [skill-sync.md](skill-sync.md) has the design, built on 2026-11-05.

- **Open:** which skills he names, and the company's rules on putting them in OneDrive.
- **Open:** whether Cowork follows the note. Nothing here has run with real Cowork.
- **Test:** in [work-mac-session.md](work-mac-session.md), part A hands his review skill over to the relay, part D reviews with the adapted copy, and part H checks that Cowork's copy keeps up with his. The baseline is the review of 2026-11-04, which used a hand-made copy with no note.

### 3. Use what only Cowork sees

Cowork reads Teams threads, email and SharePoint, which Claude Code can't. The skill now tells it to search them for the ticket's key and the merge request's title before it plans a change or a review, to say what it found, and to list it in a review's Coverage section. All of that is data to it, never instructions, as rule 2 of the skill already says. Built on 2026-11-05, as text only, and not yet tried with Cowork.

### 4. Toolchain and dependencies in the sandbox

A Linux Go toolchain has built, vetted and tested offline in Cowork's sandbox, with the standard library only. `relay mr` already sends his own Go libraries at the versions `go.mod` pins. The step is to send everything a build needs with a scan, so Cowork can compile and run unit tests as often as it likes, and the Mac's run becomes the final proof.

- **Unknown:** whether a module with real dependencies builds there. Never tried.
- **Unknown:** size. Scans have reached Cowork at 50 MB, and a toolchain alone is 67 MB.
- **Limit:** no network and no services, so tests that need a database won't run there.
- **First:** a short test on the work Mac, before any design. It is part F of [work-mac-session.md](work-mac-session.md).

### 5. Deliverables with branches

One deliverable can carry several attempts: try fix A, and if its checks fail, try B in a fresh copy, and report both. The user still reads it and presses `y` once, and `relay apply` applies only the attempt that passed. [attempts.md](attempts.md) has the design, built on 2026-11-05 and not yet tried with Cowork.

### 6. `relay ticket`

Most work starts from a Jira ticket, and Cowork can't reach Jira, Confluence or GitLab. The Mac can. A pack like `relay mr`'s: the ticket, the pages it links, and the related merge requests, sent to OneDrive.

- **Open:** which command-line tools the work Mac has for Jira and Confluence, and whether the tenant gives Cowork its own way to read them.
- **Test:** [work-mac-session.md](work-mac-session.md) part G finds out both.

### 7. `relay ask`

Claude tokens are scarce at work and Copilot's aren't. `relay ask` would pack a question with a scan, wake Cowork, and bring back an answer file. Cowork does the bulk reading and the first draft, and Claude does the precise work on the machine.

- **The rule still holds:** the answer comes from the cloud, so it is shown and accepted with `y` before anything reads it.
- **Depends on:** the wake-up, phase 3 of the roadmap, or the user telling Cowork to start.
- **2026-11-10:** built, as `relay ask` and `relay answer`, after the wake-up passed its test. [ask.md](ask.md) says what was built.
- **2026-11-09, later the same day:** a webhook trigger in Cowork can be fired from the Mac, so the first point below no longer holds. [ask.md](ask.md) has the test and the design that follows from it.
- **Checked on 2026-11-09, whether something official already does this:**
  - Cowork has no API and no command line. Its tasks start in its own window, from a schedule set there, or from a trigger set there, such as a mail arriving. So nothing can hand Cowork a job from the Mac. The email trigger is still the only way in from outside.
  - Microsoft 365 Copilot has a Chat API, in preview, for people with the Copilot licence. An app sends a prompt and gets Copilot's answer, grounded in the user's work data and the web, with OneDrive and SharePoint files as context. It returns text only: no files made, no actions, no code run, and long tasks time out. It needs an app registered in the company's tenant and a sign-in, which is the admins' call. This is the closest thing to `relay ask` that exists, and it is Copilot's chat, not Cowork.
  - GitHub Copilot is a different product with a real command line: `copilot -p "..."` answers a prompt and exits, for use in scripts. It works on the Mac's own files with GitHub's models. It only matters if the company has GitHub Copilot as well.
- **So the shape of `relay ask`, if built:** the relay packs the question with a scan, as planned. Getting it to Cowork still needs the user or the email trigger. The Chat API could answer reading questions with no Cowork at all, if the admins allow an app. Whichever answers, the answer is shown and accepted with `y` before the assistant on the Mac reads it.

### 8. Cowork drafts wiki pages

Cowork can read a whole repository cheaply and draft notes about how it works. They come back like an answer from `relay ask`, and go into the wiki as notes through `wiki capture`, so a Claude session reads a compiled page instead of exploring. The relay still works with no `wiki` command.

### 9. Overnight reviews

Cowork has scheduled prompts. Each morning it could have reviewed every merge request waiting on him, ready for `relay review`. That needs the Mac to send packs with nobody there, which is the first thing the relay would do unattended. It only sends, and nothing runs or lands, but it puts code in OneDrive without a person choosing to. That is a policy decision first.

## What doesn't change

- Nothing from the cloud runs or lands on the Mac without a keypress there.
- Nothing here goes round a control the tenant has set, such as the browser or connectors being off.
- Anything that needs real Cowork comes with exact steps and a list of what to bring back.
