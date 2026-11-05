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

- The guided field test. The skill is text, and `relay field-test` has only run in smoke tests. Not known: whether Cowork keeps to one step at a time, whether it keeps the user's work out of the report, and whether the report is good enough to act on.

- Installing with Homebrew on the work Mac. It has been installed from the tap on one personal Mac only.

- Attempts, with real Cowork. They have only run in smoke tests. Not known: whether Cowork writes real alternatives or pads a deliverable, and how long several sets of builds take in one run on real code.
- The skill's instruction to look in Teams, email and SharePoint. It is text only, and nobody has seen what Cowork does with it.

- Skill sync, with real Cowork and real OneDrive. It has only run in smoke tests. Not known: whether Cowork follows the note on a copied skill, whether the marker lines reach it, whether it cites the stamp in a review, and how the relay reads a copy that OneDrive has made cloud-only. Parts A, D and H of `design-and-decisions/work-mac-session.md` are the test.

- The prompt that reads `/dev/tty`. It has answered through a pseudo-terminal in the smoke tests, on macOS and Linux. Nobody has typed at it by hand in Apple's Terminal, and `v` hasn't opened a real pager through it.

- The standalone `relay` command on the work Mac. On 2026-11-05 it was cloned and linked there, `relay setup` installed the skill into the real OneDrive folder, and it printed `reviews` and `clones` from the old settings file without asking. `relay setup --skills` also ran there once, found a skill of the same name that the relay hadn't made, and left it alone. Still untested there: the reinstalled skill with real Cowork, and every other command.
- `relay mr` and `review` with Copilot Cowork ran once on a real merge request on 2026-11-04, and every finding was reading only. The checks, the Coverage section and the fuller skill instructions came after that, so whether Cowork follows them is untested, and its findings have never been compared with a Claude review. A second pass in that session sent real runs to the Mac, which is how a hook spoiling the tree came to light, and the fix, `safe_worktree`, has only run in smoke tests. `apply` has only run in smoke tests.
- Copilot Cowork reading a repository's wiki from `relay scan`. It has only run in smoke tests, against a fake OneDrive folder.
- The `remote-pair-run` skill and the relay on real code. Whole rounds passed on a throwaway repository from Apple's Terminal on 2026-11-04, with nothing attached and no Always Keep. The relay's refusal message has only run against an imitation, because iTerm wasn't refused in that test, and later read a file it had been refused an hour before. Why is unknown.

## Done

### Cowork guides the test, and reports on it (2026-11-05)

- **Why:** the first field tests went well when Cowork led them and wrote a labelled report. That was set up by hand each time, and the steps had since been written only for a person to follow.
- **What changed:** `relay setup` installs a second skill, `relay-field-test`. `relay field-test` puts a note about the Mac's setup in OneDrive, with no paths or names in it, and a prompt on the clipboard. Cowork then gives one step at a time and writes a report for the relay's developer, which comes back through `relay review`. This is version 0.2.0.

### Install with Homebrew, and releases (2026-11-05)

- **Why:** installing meant cloning the repository and linking a script by hand, and updating meant `git pull`. There were no versions.
- **What changed:** `brew install broxgit/tap/llm-relay` installs it. A release is a tag, and `relay --version` says which one you have. `relay scan` and `relay mr` say when Cowork's copy of the skill isn't this relay's, because an upgrade doesn't touch OneDrive. `docs/releasing.md` has the steps.

### Several attempts in one run (2026-11-05)

- **Why:** every round costs a keypress and a few minutes of OneDrive. When Cowork couldn't tell which of two or three fixes would work, it had to try them in separate rounds.
- **What changed:** `runlib.sh` version 5 has `attempt`, which runs one way of doing it in a fresh worktree with hooks off, and keeps its results to itself. A run passes if one attempt does, and its summary says which. `relay apply` applies only that attempt's patches, and only when the report in OneDrive is the file this Mac kept. The skill says when to use attempts.
- **Also:** the skill now tells Cowork to look in the user's Teams chats, email and SharePoint for the discussion behind a change, and to say what it found.

### Your own skills go to Cowork, adapted (2026-11-05)

- **Why:** Cowork reads the same `SKILL.md` shape as Claude, and the first real review showed it skipping steps of a skill it couldn't do. Reviews are the largest use, and they follow a skill.
- **What changed:** `relay setup --skills NAMES` copies the skills you name to Cowork's folder. Each copy is your skill with a note on top saying what to do differently there, and a stamp of what it was made from. `setup`, `scan` and `mr` make a copy again when your skill changes. A copy changed in OneDrive is never replaced unasked. `relay skills` reports where each stands, and `relay review` warns when a review cites an older copy.

### The keypress gate holds against pipes and variables (2026-11-05)

- **Why:** `printf y | RELAY_TEST_TTY=1 relay run ...` ran a deliverable with no terminal. The cloud couldn't use that, but an agent or script on the Mac could.
- **What changed:** `run`, `review` and `apply`, and the questions in `setup` and before the `mr` checks, need a terminal on standard input and read the answer from `/dev/tty`. `RELAY_TEST_TTY` is gone. The tests type at a pseudo-terminal with `tests/type-keys.py`. The question shows at the terminal even when the output goes to a file. The skill tells Cowork never to hand over `relay mr --checks`.
- **What it doesn't stop:** a program that drives a terminal of its own.

### Split out of llm-wiki (2026-11-05)

- **Why:** one repository per tool. Only about 35 lines of `wiki.sh` were about the relay, and every wiki user was getting it.
- **What changed:** the relay's files came across with their history. `wiki relay` became `relay`, and `wiki setup copilot-cowork` became `relay setup`. The wiki command is now optional. `--collection` went with the move, so set `WIKIS_DIR` to pick a collection.
