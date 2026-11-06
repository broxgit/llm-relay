# The guided way in

**Status: Brock said to design and build it on 2026-11-06. The terminal side and the skill's side are built, as 0.2.5, and ran with real Cowork once that day: Cowork read the note, asked the one question with no menu, and gave its steps in the short block. The practice round followed as 0.2.7, and has only run in smoke tests.** It is the "Team use" part of [roadmap.md](roadmap.md).

The relay was built for one person who knows it well. It is now meant for the developers on his team too, of varying skill levels. They shouldn't need to know its commands or its unwritten rules to begin.

## What a new person had to know

Before this, all of it came from `docs/using.md` or from being told:

- Which command starts each thing: `relay scan`, `relay mr`, `relay review`, `relay apply`.
- What to say to Cowork after each one.
- To run `relay setup` again after an upgrade, wait 10 minutes, and start a new session.
- To use Apple's Terminal.
- That `relay mr` needs `glab`, which they found out when a review failed.

## Three rules

1. **One command to learn.** `relay start`.
2. **The terminal says what's next.** Every command ends by saying what to do or what to tell Cowork.
3. **Cowork gives one step at a time,** in the same block each time.

The second rule carries the most weight, on purpose. The relay prints the same thing every time and can be tested without Cowork. Cowork has drifted from instructions before: in the third field test it needed a second ask on 4 of 9 steps. With the loud block it did better, about 30 of 33 in the test of 2026-11-06, but the terminal is still the part that can't drift.

## `relay start`

```
relay 0.2.5

What you can do on this Mac:
  Change code with Cowork           ready
  Review a merge request            needs glab: brew install glab, then sign in with: glab auth login
  Run Go checks in a review         ready
  Send a repository's wiki with it  needs wiki: optional, from github.com/broxgit/llm-wiki
Clones are looked for under ~/dev, and reviews are saved under ~/mr-reviews. relay setup changes either.

Cowork takes up to 10 minutes to see its new skills. It's 09:42 now, so start at 09:52.
A prompt for Cowork is on your clipboard.
Next: at 09:52, open a new Cowork session and paste it.
```

- **It asks nothing.** `relay setup` still asks where clones and reviews live. `relay start` uses what's set, or the defaults, and says where to change them.
- **It gets Cowork this relay's skills.** If Cowork has none, or has an older relay's, it installs them and says when to start, by the clock. `relay scan` and `relay mr` only say that the copy is stale. So `relay start` is also the command for after an upgrade.
- **It doesn't write over what it can't read.** See "A copy that can't be read", below.
- **It writes a note for Cowork,** at `Documents/Cowork/relay/start/note.txt`: which relay and runlib, the terminal app, what the Mac is set up for, how many runs it has done, and where the user's own skills stand. It holds no paths.
- **It is for every session,** not only the first. The second time it takes a second and has nothing to wait for.

## One list of what each thing needs

`FEATURES` in `relay.sh` has a line for each thing the relay does and the tools it needs. `tool_hint` has how to get each tool. Three places read them:

- `relay start` and `relay setup` print the list.
- `relay start`'s note gives it to Cowork, which then knows to hand over an install line first.
- A command that lacks a tool stops with the same line, through `needs_tool`.

A new dependency, such as a Jira tool for `relay ticket`, is one line in each. No message can leave it out. Tools stay optional: someone who never reviews a merge request isn't made to install `glab`.

## What the terminal says next

Most commands already ended with a next step: `Now tell Cowork: done`, `Now tell Cowork: read ...`, the prompt from `relay mr`. Two things were missing.

- **`relay scan` puts its line on the clipboard,** as `relay mr` does. Cowork often asks for two scans in one line, so scans within two minutes of each other add up on the clipboard, and the last doesn't wipe the first. It only happens at a terminal, and never for a scan that `relay mr` makes for `--also`.
- **`relay setup` ends by pointing at `relay start`.**

## The skill's side

`remote-pair-run` has two new sections.

**When the user starts with `relay start`.** Read the note. Compare its `relay:` and `runlib:` lines with the skill's own, and stop if either differs, because a stale copy hands over wrong commands. Then ask one thing: "What are you working on?" There is no menu. A menu adds a turn before anything useful happens, and it is a second list of features that would go stale. From the answer, Cowork gives the first step.

**How to give the user a step.** The block from the guided test, made lighter for everyday use:

```
---
## 🔴 YOUR TURN

**🚦 DO THIS**
1. The one command, in its own code block.

**👀 EXPECT**
- Only when something would surprise them: a wait, a question the relay asks, a key to press.

**💬 THEN TELL ME**
- What to send back.
---
```

The guided test's block has six parts, which suit a test where the user is a test subject. On someone's twentieth real round they are noise. Here `EXPECT` appears only when there is a wait, a question or a key, and `THEN TELL ME` is usually the one word `done`.

The skill also says which relay it is for, as the test's skill does, so a stale copy can be told from the note. That makes three lines to change at a release, and a smoke test fails if they differ.

## Keeping it current

Brock's rule, from 2026-11-06: as features are added, the guided way in is updated to reflect them. A guide that lists last month's features is worse than none, because people trust it.

So it is held by a test, not by memory. `FEATURES` has, for each thing the relay does, the command that begins it. The smoke tests fail when:

- a feature's command isn't named in the skill's starting section, so Cowork wouldn't know when to give it
- a tool has no line on how to get it
- a command stops for a tool that isn't in `FEATURES`, so `relay start` wouldn't have said so first
- a command exists that the skill never names, and that isn't on the short list of commands a person runs on their own

What the test can't see is whether the words are good. A new feature still needs its part of `docs/using.md` written, and the tests don't read that file.

## A copy that can't be read

macOS has refused one terminal app a file in OneDrive that another app reads. When the relay couldn't read a skill copy's stamp, it called the copy "made by hand", whatever the reason. A note made from iTerm on 2026-11-06 said that of a copy the relay had made the day before. That it was a refused read is likely and not confirmed.

Now a copy that is there and can't be read is its own state. `relay skills`, `relay setup`, `relay start` and the notes say so, say that another terminal app may be able to read it, and leave it as it is.

## The practice round

Built on 2026-11-06, as 0.2.7. It has only run in smoke tests.

A new person should be able to press `y` on code that doesn't matter before their own.

- `relay practice` makes a small repository at `~/relay-practice`, holding one file that says `hello`, and puts a prompt on the clipboard. It shares its beginning with `relay start`, so the note and the checks are the same.
- Cowork walks one real round on it: a scan, a patch that adds a line of Cowork's own, a run with **v** and **y**, an apply, and a look at the file before the clean-up. There is no diagnostic report.
- The line is Cowork's to choose, on purpose. The person sees something written in the cloud arrive in a file on their Mac, having pressed a key at each step.
- The skill's starting section offers it when the note says nothing has run on that Mac yet.

It waited until `relay start` had been tried with real Cowork, because it leans on the same block and the same note. That try went well on 2026-11-06, so it can be built.

## Not here

- **A plain summary before `y`.** Today `v` shows a page of shell script, which a less experienced engineer can't judge. The relay would say in its own words what a deliverable touches and runs, read from the files and not from what Cowork says about them. It needs a design of its own.
- **Checks beyond Go,** `relay ticket`, and a wake-up by email. [roadmap.md](roadmap.md) and [leverage.md](leverage.md) have them.

## Not known

- Whether Cowork stops when its copy of the skill is stale. The first real run had a current copy.
- Whether the lighter block holds late in a long session. It held in the first real run.
- Whether people run `relay start` each session, or only once.
- Whether writing to the clipboard on every scan is welcome over weeks of use.
