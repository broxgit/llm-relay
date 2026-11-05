# Testing with Cowork: the work-Mac session

**Status: part A ran on 2026-11-05. Nothing else here has run.** This is phase 2 of the [roadmap](roadmap.md), and it tests everything in [leverage.md](leverage.md) that is built.

Cowork is only on the work Mac, so this is the only way anything gets tried with real Cowork and real OneDrive. It walks through each thing the relay does, says what you should see, and gives you prompts to paste into Cowork so it reports on how its side went.

## How to use this

- **Run** means a command in Apple's Terminal. macOS can refuse other terminal apps on OneDrive files.
- **Expect** is what the relay prints when it works. Anything else is a finding, so keep it.
- **Ask Cowork** is a prompt to paste as it stands. Each one asks Cowork to check, not to recall.
- **Note** is something to write down.

What Cowork tells you about itself is its own account. It is useful, and it can be wrong, so where a prompt says "run it" or "quote it", hold it to that.

To keep the terminal's output, use Terminal's Shell menu, then Export Text As, at the end of each part.

## The parts

| Part | Tests | Minutes | Needs |
|---|---|---|---|
| A | Install, settings, your own skill in Cowork | 10, then a 10 minute wait | The install ran on 2026-11-05. Repeat the update after each merge |
| B | A whole round, a failure, `n`, `apply`, several attempts | 20 | A throwaway repository |
| C | Another branch, and the wiki copy | 5 | The same repository |
| D | A merge request review, with checks and your skill | 20 | One real merge request |
| E | Whether Cowork can be woken through Teams | 15 | Teams |
| F | A build with real dependencies in Cowork's sandbox | 15 | A small Go repository of yours |
| G | What Cowork can reach for Jira and Confluence | 5 | A ticket key |
| H | Whether Cowork's copy of your skill keeps up with yours | 5 | Part A's skill step |

A to D prove what is built. E, F and G answer questions that decide what gets built next. If time is short, do A, B and D.

## A. Update, and hand your skill to the relay

The first install is in the [README](../README.md#install). After that, run:

```bash
git -C ~/dev/llm-relay pull && relay setup
```

Expect `installed:` with the skill's folder, then `relay setting:` lines for `reviews`, `clones` and `skills`.

If it says a skill is already in Cowork's folder and the relay didn't make it, it prints three steps. They are:

1. See how the hand-made copy differs from yours.

   ```bash
   diff -r ~/.claude/skills/mr-review "$(ls -d ~/Library/CloudStorage/OneDrive-* | head -n 1)/Documents/Cowork/skills/mr-review"
   ```
2. Put anything in it that is only for Cowork into `~/.claude/skills/mr-review/COWORK.md`.
3. Move the hand-made folder out, and run setup again.

   ```bash
   mv "$(ls -d ~/Library/CloudStorage/OneDrive-* | head -n 1)/Documents/Cowork/skills/mr-review" ~/mr-review-by-hand
   ```

   ```bash
   relay setup
   ```

Expect `skill mr-review: copied to Cowork`, with eight characters in brackets. That is the stamp. Note it.

Run:

```bash
relay skills
```

Expect `mr-review: in step`.

Wait 10 minutes, then start a new Cowork session. Cowork's copy of a skill can lag OneDrive.

Ask Cowork:

```text
Before we start, check and report. Don't change anything.
1. List every skill you have loaded.
2. For remote-pair-run: open its runlib.sh and quote the line that sets RUNLIB_VERSION.
3. Does its SKILL.md have a section called "Several attempts in one run"? Quote that section's first sentence.
4. Does your mr-review skill begin with a note from relay? If so, quote the line that says how to cite the skill.
```

Expect `RUNLIB_VERSION=5`, the attempts section, and a citation line holding the stamp you noted. An older version or a missing section means Cowork still has an old copy: wait five more minutes and start another session.

Note: what it listed, the version, and whether the stamp matches.

## B. One round on the throwaway repository

1. In the repository, run:

   ```bash
   relay scan
   ```

   Expect `Scanned`, then `Sent to OneDrive:`, then `Now tell Cowork: read Documents/Cowork/relay/scans/<name>.txt`.

2. Ask Cowork, with the name from that last line:

   ```text
   Read Documents/Cowork/relay/scans/<name>.txt from my OneDrive, with nothing attached. Tell me its branch, commit, taken and wiki lines. Then get the archive it names, check its hash, and tell me how long each read took.
   ```

3. Ask Cowork:

   ```text
   Using remote-pair-run, make a small change in that repository: add a comment to the top of the README. Give me the one command to run.
   ```

   Expect a command that starts with `relay run`, not `wiki relay run`.

4. Run that command. Expect `Relay run started at`, then the deliverable's files, then `Run it? [y]es, [v]iew the files, [n]o:`. Press `v`, read, quit the pager, then press `y`. Expect `Sent to OneDrive:` and `Now tell Cowork: done`. Tell Cowork "done".

   Note: how long it waited before the files were ready. Nobody had typed at this prompt by hand before today, so also note anything odd about it.

5. Ask Cowork:

   ```text
   Now make a change whose first run you expect to fail, so we both see a failing report. After I run it, read the report, tell me its last ten lines exactly, and then fix it.
   ```

   Run each command it gives you. On one of them press `n`. Expect `Nothing ran, and no report was sent.`

6. After a PASS, ask Cowork for the `relay apply` command and run it. Press `y`. Expect `Applied, and nothing is committed.` Then run `git status`, and expect the change in your working tree with nothing committed.

7. Ask Cowork:

   ```text
   Give me one deliverable with two alternative ways of making a change, using your skill's section on several attempts. Make the first attempt fail on purpose, so we see the second one pass. Say in a line each what each attempt tries.
   ```

   Run it. Expect the report to end with `attempts: 2 tried`, a line for each attempt, and `attempt passed:` with a name. Then run the `relay apply` command it gives you. Expect `Attempt:` with that name before it asks.

Ask Cowork, to close the part:

```text
Write a short report on this part for the relay's developer. For each thing you did, say which tool you used and how long it took if you know. Mark each claim "validated", naming the report that shows it, or "not validated". List anything in the remote-pair-run skill that was unclear or wrong, or that you had to work around, and quote the line.
```

## C. Another branch, and the wiki copy

Run, with a branch other than the one you're on:

```bash
relay scan --branch main
```

Expect `Scanned`, with `from origin/main` or `from your local main`, and `uncommitted changes left out`.

Ask Cowork:

```text
Read the scan note again. Quote its source, branch, taken and wiki lines. Is this a newer copy than the one you read before, and how do you know? If the wiki came with it, open repo-wiki/index.md and cite one page by its path.
```

Note: whether it noticed the copy was new. Its download tool can keep an old copy.

## D. One real merge request

1. Run, with no other flags:

   ```bash
   relay mr <url>
   ```

   Expect a question that starts `Run go build, vet, test and mod tidy on a temporary copy`, naming the author. Press `y`. Expect a line for each check, then `Packed`, then `Paste this into Cowork. It's on your clipboard:`.

   Note: how long the checks took, and whether any failed.

2. Paste the prompt from your clipboard into Cowork.

3. Run the `relay review` command it gives you. Expect `What <file> says it covered:` with a list. A warning that there's no Coverage section is a finding. Press `y`. Expect `Saved:` with the file's path.

4. Ask Cowork:

   ```text
   Pick the finding in your review that most depends on running the code, and prove or disprove it with a run, starting with safe_worktree.
   ```

   Run the command. In the report, look for `RESULT worktree identical to`, `RESULT tracked files unchanged in the worktree` and `RESULT your checkout unchanged`. Tell Cowork "done".

5. Ask Cowork:

   ```text
   About the review you just wrote, answer as a table, and check before you answer.
   1. How many changed files does the note say there are? Which did you read in full, and which did you skip?
   2. Which steps of my mr-review skill did you follow, skip or change, and why?
   3. Did the checks in mr/checks run? What did you take from them?
   4. What did you look for in my Teams chats, email and SharePoint, and what did you find?
   5. Which findings came from a sub-agent, and which of those did you re-check yourself?
   6. How did you cite the mr-review skill in the Coverage section? Quote it.
   ```

   Note: whether the stamp it quotes is the one from part A. If `relay review` warned that the review used an older copy, note that too.

The review of 2026-11-04 used a hand-made copy of the skill, with no note from the relay. That is the baseline to compare this one with.

## E. Whether Cowork can be woken through Teams

These decide whether the wake-up in [design.md](design.md#design-2-wake-cowork-without-typing-done) is built.

1. In Teams, open a chat with yourself, choose Workflows, pick "Send webhook alerts to a chat", save it, and copy the address. If you can't, note what stopped you and skip the rest of E.
2. Run the first command and paste the address at the silent prompt. Then run the second.

   ```bash
   read -rs WAKE
   ```

   ```bash
   curl -sS -m 10 -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' -d '{"type":"message","attachments":[{"contentType":"application/vnd.microsoft.card.adaptive","content":{"$schema":"http://adaptivecards.io/schemas/adaptive-card.json","type":"AdaptiveCard","version":"1.2","body":[{"type":"TextBlock","text":"relay-report probe 1"}]}}]}' "$WAKE"
   ```

   Expect a status code starting with 2, and the message in the chat. Note who it appears from.

3. Ask Cowork:

   ```text
   Set a trigger: when a message containing "relay-report" arrives in my Teams chat with myself, continue this conversation and tell me exactly what the message said and when you saw it. Once it's made, tell me its settings, including whether it needs my approval each time.
   ```

   Run the `curl` command again. Note whether it fired, how long it took, whether it was the same conversation, and whether it asked for approval.

4. Open a second Cowork conversation and set the same trigger there. Run the `curl` command once more. Note which of the two conversations woke.

Delete the workflow afterwards if you don't want it kept.

## F. Dependencies in Cowork's sandbox

This tests [leverage step 4](leverage.md#4-toolchain-and-dependencies-in-the-sandbox). The largest file tried with Cowork so far is about 50 MB and a Go toolchain is larger, so a failure to read the file is itself a finding.

1. Ask Cowork:

   ```text
   In your sandbox, run uname -m and go version, and tell me exactly what each printed.
   ```

   Expect an architecture, and no Go.

2. Pick a small Go repository of yours that uses your internal libraries. Make a scratch copy with its dependencies vendored, so your real clone isn't changed.

   ```bash
   git clone -q <path-to-repo> /tmp/dep-probe && cd /tmp/dep-probe && go mod vendor && cd /tmp && tar --exclude .git -czf ~/dep-probe.tar.gz dep-probe
   ```

3. Download the Linux Go tarball from https://go.dev/dl/ that matches the architecture from step 1 and the Go version in the repository's `go.mod`.

4. Note both files' sizes, then copy both to OneDrive. These assume the Go tarball is in `~/Downloads`.

   ```bash
   ls -l ~/dep-probe.tar.gz ~/Downloads/go*.linux-*.tar.gz
   ```

   ```bash
   cp ~/dep-probe.tar.gz ~/Downloads/go*.linux-*.tar.gz "$(ls -d ~/Library/CloudStorage/OneDrive-* | head -n 1)/Documents/Cowork/relay/scans/"
   ```

5. Ask Cowork:

   ```text
   With nothing attached, read dep-probe.tar.gz and the Go tarball from Documents/Cowork/relay/scans in my OneDrive. Tell me how long each took to arrive and its size. Extract both under /tmp. Set up Go as your remote-pair-run skill says under "Compile before you hand over", but with GOFLAGS=-mod=vendor. In the repository, run go build ./..., go vet ./... and go test ./..., and report each result with its last ten lines of output. For each test that failed, say whether it needed the network or a service.
   ```

6. Note: whether each file arrived, whether it built, and which tests failed and why.

Clean up:

```bash
rm -rf /tmp/dep-probe ~/dep-probe.tar.gz
```

The two copies in OneDrive's `scans` folder are yours to delete in Finder.

## G. What Cowork can reach for Jira and Confluence

This tests [leverage step 6](leverage.md#6-relay-ticket).

1. Ask Cowork, with a real ticket key of yours:

   ```text
   With nothing attached, can you read Jira ticket <KEY> and the Confluence page it links? Try it. Say exactly which tool you used, or the exact error that stopped you.
   ```

2. Run:

   ```bash
   command -v jira acli glab
   ```

3. Note Cowork's answer and the command's output.

## H. Whether Cowork's copy of your skill keeps up

This tests [skill-sync.md](skill-sync.md). It needs the skill step of part A, and it can go in any session after that.

1. On the Mac, change your skill by one line, such as a blank line at the end of `~/.claude/skills/mr-review/SKILL.md`. Then run:

   ```bash
   relay skills
   ```

   Expect `your skill has changed since Cowork's copy was made`.

2. In any repository, run:

   ```bash
   relay scan
   ```

   Expect `skill mr-review: Cowork's copy was out of date, so it was made again`, with a new stamp.

3. Ask Cowork, in the session you already have open:

   ```text
   Open SKILL.md for mr-review in Documents/Cowork/skills in my OneDrive, and compare it with the copy you loaded when this session started. Quote the "write this one as" line from each. Are they the same? Which tools does the note say you don't have here?
   ```

   Expect two different stamps: the session's copy is the older one. That is the lag the stamp is there to catch.

4. Undo your one-line change, and run `relay setup`, so the copy matches your skill again.

5. Note: whether Cowork saw the note at all, both stamps, and the tools the note listed.

## Prompts for any time

Paste these whenever something looks off.

**What Cowork has, right now:**

```text
Check, don't recall. In your sandbox run: uname -m; command -v git python3 node go mkfifo cmp seq which curl; and try to reach any public address. Tell me what each printed. Then say whether your clone of my repository is still in your working area.
```

**Whether its skill is current:**

```text
Read SKILL.md and runlib.sh for remote-pair-run from Documents/Cowork/skills in my OneDrive. Compare them with the copies you loaded at session start. Are they the same? Quote the RUNLIB_VERSION line from each.
```

**After a run that looked wrong:**

```text
List Documents/Cowork/relay/<task-folder>/reports in my OneDrive and read the newest file. Quote its header and its last twelve lines exactly. Does its version match the one you last published, and is its started time after you published? If not, say so and stop.
```

**After a PASS you don't trust:**

```text
Doubt that PASS. Which checks ran, and did each one test what you meant it to? Was any output compared against something empty or unchanged? What would still pass if your change did nothing?
```

**After publishing:**

```text
You just published. Read manifest.txt back from your output folder and check every file against it. How many seconds passed before they all matched, and which file was last?
```

**What the skill gets wrong:**

```text
If you could change three things in the remote-pair-run skill to make this go better, what would they be? Quote the lines you'd change and write the replacement.
```

**At the end of the session:**

```text
Write a report of this whole session for the relay's developer, to be read by someone who wasn't here. Go in order. For each step: what you were asked, what you did, which tool you used, how long it took if you know, and "validated" with the report's name or "not validated". Then list every time you waited, retried, lost your working area, or worked around a missing tool. End with what you would test next.
```

## Bring back

Paste these into the session that is building the relay. Leave out anything you wouldn't want outside work, such as ticket text or code.

- The terminal text of each part you ran.
- Cowork's answer to each "Ask Cowork" in the parts you ran.
- Cowork's end-of-session report.
- For part E: what happened at each of the four steps, with the timings. Not the webhook address.
- For part F: both file sizes, whether each arrived, and the build and test results.
- For part G: Cowork's answer, and the output of `command -v jira acli glab`.
- Your own notes: what felt slow, what you had to do by hand, and anything you had to ask Cowork twice.
