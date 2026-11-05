# Roadmap

What's planned for the relay, and what's still untested. When an item is finished, move it to Done with the date and what changed.

## Next

### Wake Copilot Cowork with no one typing

- **Why:** the relay removed the attachments, but the user still tells Cowork "done" after each run.
- **What the tests showed (2026-11-03, two sessions):** Cowork picks the skill unprompted, and reads OneDrive by path with no attachment, including a `git bundle` in a tar.gz, with the bytes intact. An email trigger woke the same conversation in 8 to 67 seconds, even with Cowork closed, and refused a stale report. An uploaded Go toolchain ran offline. Cowork's browser refused, with browsing not enabled for the workspace. Running from the synced folder is fragile: `bash` was killed once and refused once with `Operation not permitted`, and a stale report got sent after the refusal. AppleScript can't send the email when the user is on Outlook on the web.
- **Sketch:** after sending a report, `relay run` posts through a Teams workflow webhook, and a Cowork trigger on that message reads the report and carries on.
- **Open:** whether the tenant allows the webhook, and whether a bot's message fires a trigger. Whether a trigger whose own instructions say to fix a FAIL can publish the fix is still untested, and only matters once this works. Also open: does the toolchain survive an idle gap?
- **After that:** a direct bridge, as an MCP connector through a dev tunnel, could replace the relay. It's a public URL into a work laptop, and Cowork also reads email and web pages, so it needs IT's approval and no general shell.

## Untested

Things that have never been run for real. Treat them as unproven until crossed off.

- The standalone `relay` command, its `relay setup`, and the reinstalled skill with real Cowork and real OneDrive. They've only run in smoke tests since the split from llm-wiki, because Cowork is only on the user's work Mac. Reading `~/.config/llm-wiki/relay` on that Mac is the first thing to check.
- `relay mr` and `review` with Copilot Cowork ran once on a real merge request on 2026-11-04, and every finding was reading only. The checks, the Coverage section and the fuller skill instructions came after that, so whether Cowork follows them is untested, and its findings have never been compared with a Claude review. A second pass in that session sent real runs to the Mac, which is how a hook spoiling the tree came to light, and the fix, `safe_worktree`, has only run in smoke tests. `apply` has only run in smoke tests.
- Copilot Cowork reading a repository's wiki from `relay scan`. It has only run in smoke tests, against a fake OneDrive folder.
- The `remote-pair-run` skill and the relay on real code. Whole rounds passed on a throwaway repository from Apple's Terminal on 2026-11-04, with nothing attached and no Always Keep. The relay's refusal message has only run against an imitation, because iTerm wasn't refused in that test, and later read a file it had been refused an hour before. Why is unknown.

## Done

### Split out of llm-wiki (2026-11-05)

- **Why:** one repository per tool. Only about 35 lines of `wiki.sh` were about the relay, and every wiki user was getting it.
- **What changed:** the relay's files came across with their history. `wiki relay` became `relay`, and `wiki setup copilot-cowork` became `relay setup`. The wiki command is now optional. `--collection` went with the move, so set `WIKIS_DIR` to pick a collection.
