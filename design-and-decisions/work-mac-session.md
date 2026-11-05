# The work-Mac session

**Status: proposed on 2026-11-05, not run.** This is phase 2 of the [proposed roadmap](roadmap.md).

One sitting of about an hour and a half, in Apple's Terminal. Parts F, G and H can be skipped if time is short, since A to E prove the core of what is built. Phase 1 merged on 2026-11-05, so `main` is ready for it. Cowork is only on the work Mac, so this is the only way anything here gets tried with real Cowork and real OneDrive. Each part says what to run and what you should see. Anything else you see is a finding, so copy it.

## A. Install, 5 minutes

```bash
git clone https://github.com/broxgit/llm-relay.git ~/dev/llm-relay
```

```bash
mkdir -p ~/.local/bin && ln -s ~/dev/llm-relay/relay.sh ~/.local/bin/relay
```

```bash
cat ~/.config/llm-wiki/relay
```

```bash
relay setup
```

```bash
ls ~/.config/llm-relay
```

Expect `installed:` with the skill's folder, then `relay setting: reviews=` and `relay setting: clones=` matching the old file, with no question asked. The last command should find no such folder, because nothing new was written. 

Optional, to test that a second skill loads ([leverage step 2](leverage.md#2-sync-his-claude-skills-to-cowork)): copy one of your own Claude skills into Cowork's skills folder, before the wait. Pick the merge request review skill if you have one. First check that the company allows that skill's text in OneDrive. If not, skip this step. List the OneDrive folder first.

```bash
ls -d ~/Library/CloudStorage/OneDrive-*
```

Then copy the skill, with that folder in place of the angle brackets.

```bash
cp -R ~/.claude/skills/<skill-name> "<that folder>/Documents/Cowork/skills/"
```

Then wait 10 minutes and start a new Cowork session.

## B. One round on the throwaway repository, 15 minutes

1. In the repository, run `relay scan` and tell Cowork the line it prints.
2. Ask for a small change. The command Cowork gives you should start with `relay run`, not `wiki relay run`. That shows it loaded the new skill.
3. Run it. Press `v`, read, quit the pager, then press `y`. Tell Cowork "done".
4. Ask for a change whose first run it expects to fail, then let it fix it.
5. On one of those commands press `n`. Expect "Nothing ran, and no report was sent."
6. After a PASS, ask for the `relay apply` command, run it, press `y`, and run `git status`. Expect the patch in your working tree and nothing committed.
7. Ask for a change with two alternative fixes in one deliverable, as its skill's section on several attempts describes. Run it. Expect `attempts: 2 tried` and an `attempt passed:` line at the end of the report. Then run the `relay apply` command it gives you, and expect it to name that attempt before it asks.

## C. Another branch and the wiki copy, 5 minutes

```bash
relay scan --branch main
```

Ask Cowork to quote the note's `source:` and `wiki:` lines. If a wiki went with it, ask it to cite one page from `repo-wiki/`.

## D. One real merge request, 20 minutes

1. Run `relay mr <url>` with no other flags. When it asks about the checks, press `y`.
2. In Cowork, before you paste anything, ask "Which skills do you have?" and note whether the skill you copied in part A is listed. Skip this if you skipped the copy.
3. Paste the prompt from your clipboard into Cowork.
4. Run the `relay review` command it gives you. Note whether it prints "What ... says it covered" or warns that the Coverage section is missing. Press `y`.
5. Ask Cowork to prove one finding with a run. Run it, and look in the report for the lines `safe_worktree` writes about the worktree and your checkout.
6. If you copied a skill in part A, ask Cowork which of its steps it followed, which it skipped, and why.

## E. The wake-up questions, 15 minutes

These decide whether phase 3 is built. [design.md](design.md#design-2-wake-cowork-without-typing-done) says why.

1. In Teams, open a chat with yourself, choose Workflows, pick "Send webhook alerts to a chat", save it, and copy the address. If you can't, note what stopped you and skip the rest of E.
2. In Terminal, run the first command and paste the address at the silent prompt. Then run the second.

   ```bash
   read -rs WAKE
   ```

   ```bash
   curl -sS -m 10 -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' -d '{"type":"message","attachments":[{"contentType":"application/vnd.microsoft.card.adaptive","content":{"$schema":"http://adaptivecards.io/schemas/adaptive-card.json","type":"AdaptiveCard","version":"1.2","body":[{"type":"TextBlock","text":"relay-report probe 1"}]}}]}' "$WAKE"
   ```

   Expect a status code starting with 2, and the message in the chat. Note who it appears from.
3. In the Cowork session from part B, ask it to set a trigger: on a message in that chat containing `relay-report`, continue this conversation and say what the message was. Run the `curl` command again. Note whether it fired, how long it took, whether it was the same conversation, and whether it asked for approval.
4. Open a second Cowork conversation and set the same trigger there. Run the `curl` command once more. Note which of the two conversations woke.

## F. Dependencies in Cowork's sandbox, 15 minutes

This tests [leverage step 4](leverage.md#4-toolchain-and-dependencies-in-the-sandbox). The largest file tried with Cowork so far is about 50 MB and a Go toolchain is larger, so a failure to read the file is itself a finding.

1. In Cowork, ask it to run `uname -m` and `go version` in its sandbox and say what it sees. Expect an architecture, and no Go.
2. On the Mac, pick a small Go repository of yours that uses your internal libraries. Make a scratch copy with its dependencies vendored, so your real clone is not changed. Put the repository's path in place of the angle brackets.

   ```bash
   git clone -q <path-to-repo> /tmp/dep-probe && cd /tmp/dep-probe && go mod vendor && cd /tmp && tar --exclude .git -czf ~/dep-probe.tar.gz dep-probe
   ```
3. Download the Linux Go tarball from https://go.dev/dl/ that matches the architecture from step 1 and the Go version in the repository's `go.mod`.
4. Note both files' sizes, then copy both to OneDrive. These two commands assume the Go tarball is in `~/Downloads`. Put the OneDrive folder from part A in place of the angle brackets.

   ```bash
   ls -l ~/dep-probe.tar.gz ~/Downloads/go*.linux-*.tar.gz
   ```

   ```bash
   cp ~/dep-probe.tar.gz ~/Downloads/go*.linux-*.tar.gz "<that folder>/Documents/Cowork/relay/scans/"
   ```
5. Ask Cowork: "With nothing attached, read dep-probe.tar.gz and the Go tarball from Documents/Cowork/relay/scans in my OneDrive, extract them under /tmp, set up Go as your remote-pair-run skill says under 'Compile before you hand over' but with `GOFLAGS=-mod=vendor`, then run `go build ./...`, `go vet ./...` and `go test ./...` in the repository and report each result."
6. Note: did each file arrive, and how long after the copy; did it build; which tests failed, and whether the failures were for lack of network or a service.

When you are done, clean up.

```bash
rm -rf /tmp/dep-probe ~/dep-probe.tar.gz
```

The two copies in OneDrive's `scans` folder are yours to delete in Finder.

## G. What Cowork can reach for Jira and Confluence, 5 minutes

This tests [leverage step 6](leverage.md#6-relay-ticket).

1. Ask Cowork: "With nothing attached, can you read Jira ticket <KEY> and the Confluence page it links? Say exactly which tool you used, or what stopped you." Use a real ticket key of yours.
2. On the Mac, see which command-line tools are there.

   ```bash
   command -v jira acli glab
   ```
3. Note Cowork's answer and the command's output.

## H. The relay's adapted copy of your skill, 5 minutes and a wait

This tests [skill-sync.md](skill-sync.md). Do it after part D, and only if you copied a skill by hand in part A. It swaps that copy for the one the relay makes.

1. Delete the hand copy, so the relay isn't refused by a skill it didn't make. Use the OneDrive folder and skill name from part A.

   ```bash
   rm -rf "<that folder>/Documents/Cowork/skills/<skill-name>"
   ```
2. Have the relay copy it, adapted.

   ```bash
   relay setup --skills <skill-name>
   ```

   Expect `skill <skill-name>: copied to Cowork`, with eight characters in brackets. That is the stamp.
3. Check that the relay thinks the two are in step.

   ```bash
   relay skills
   ```

   Expect `<skill-name>: in step`.
4. Wait 10 minutes and start a new Cowork session. Ask: "What does the note at the top of your <skill-name> skill tell you to do differently here, and how does it ask you to cite the skill?"
5. Note whether Cowork saw the note at all, whether it repeats the stamp from step 2, and which tools the note said it lacks.

## Bring back

- The terminal output of parts A to H, as text.
- Cowork's own labelled report. Ask it: "Write a report of this session, marking each claim validated or not validated, with times."
- For part E: what happened at each of the four steps, with the timings.
- For the skill copy (parts A and D): whether Cowork listed the copied skill, and which of its steps Cowork followed, skipped, and why.
- For part F: whether each file arrived and how long after the copy, whether it built, and which tests failed and whether for lack of network or a service. Also both file sizes.
- For part G: Cowork's answer, naming the tool it used or what stopped it, and the output of `command -v jira acli glab`.
- For part H: the output of the two `relay` commands, and Cowork's answer about the note and the stamp.
- Not the webhook address. Delete the workflow afterwards if you don't want it kept.
