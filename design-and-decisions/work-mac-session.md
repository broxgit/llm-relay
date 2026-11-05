# The work-Mac session

**Status: proposed on 2026-11-05, not run.** This is phase 2 of the [proposed roadmap](roadmap.md).

One sitting of about an hour, in Apple's Terminal. Phase 1 merged on 2026-11-05, so `main` is ready for it. Cowork is only on the work Mac, so this is the only way anything here gets tried with real Cowork and real OneDrive. Each part says what to run and what you should see. Anything else you see is a finding, so copy it.

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

Expect `installed:` with the skill's folder, then `relay setting: reviews=` and `relay setting: clones=` matching the old file, with no question asked. The last command should find no such folder, because nothing new was written. Then wait 10 minutes and start a new Cowork session.

## B. One round on the throwaway repository, 15 minutes

1. In the repository, run `relay scan` and tell Cowork the line it prints.
2. Ask for a small change. The command Cowork gives you should start with `relay run`, not `wiki relay run`. That shows it loaded the new skill.
3. Run it. Press `v`, read, quit the pager, then press `y`. Tell Cowork "done".
4. Ask for a change whose first run it expects to fail, then let it fix it.
5. On one of those commands press `n`. Expect "Nothing ran, and no report was sent."
6. After a PASS, ask for the `relay apply` command, run it, press `y`, and run `git status`. Expect the patch in your working tree and nothing committed.

## C. Another branch and the wiki copy, 5 minutes

```bash
relay scan --branch main
```

Ask Cowork to quote the note's `source:` and `wiki:` lines. If a wiki went with it, ask it to cite one page from `repo-wiki/`.

## D. One real merge request, 20 minutes

1. Run `relay mr <url>` with no other flags. When it asks about the checks, press `y`.
2. Paste the prompt from your clipboard into Cowork.
3. Run the `relay review` command it gives you. Note whether it prints "What ... says it covered" or warns that the Coverage section is missing. Press `y`.
4. Ask Cowork to prove one finding with a run. Run it, and look in the report for the lines `safe_worktree` writes about the worktree and your checkout.

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

## Bring back

- The terminal output of parts A to E, as text.
- Cowork's own labelled report. Ask it: "Write a report of this session, marking each claim validated or not validated, with times."
- For part E: what happened at each of the four steps, with the timings.
- Not the webhook address. Delete the workflow afterwards if you don't want it kept.
