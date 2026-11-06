# Roadmap

What's planned for the relay, and what's still untested. When an item is finished, move it to Done with the date and what changed.

## Next

### Wake Copilot Cowork with no one typing

- **Why:** the relay removed the attachments, but the user still tells Cowork "done" after each run.
- **What the tests showed (2026-11-03, two sessions):** Cowork picks the skill unprompted, and reads OneDrive by path with no attachment, including a `git bundle` in a tar.gz, with the bytes intact. An email trigger woke the same conversation in 8 to 67 seconds, even with Cowork closed, and refused a stale report. An uploaded Go toolchain ran offline. Cowork's browser refused, with browsing not enabled for the workspace. Running from the synced folder is fragile: `bash` was killed once and refused once with `Operation not permitted`, and a stale report got sent after the refusal. AppleScript can't send the email when the user is on Outlook on the web.
- **Sketch:** after sending a report, `relay run` posts through a Teams workflow webhook, and a Cowork trigger on that message reads the report and carries on.
- **Open:** whether the tenant allows the webhook, and whether a bot's message fires a trigger. Whether a trigger whose own instructions say to fix a FAIL can publish the fix is still untested, and only matters once this works. Also open: does the toolchain survive an idle gap?
- **2026-11-06:** the user's Teams had no Workflows app, in the chat menus or the apps search on the web, so the webhook couldn't be made. Whether the company hides it isn't known. The email trigger that worked on 2026-11-03 is the route to try next.
- **After that:** a direct bridge, as an MCP connector through a dev tunnel, could replace the relay. It's a public URL into a work laptop, and Cowork also reads email and web pages, so it needs IT's approval and no general shell.

## Untested

Things that have never been run for real. Treat them as unproven until crossed off. The field test of 2026-11-06 crossed most of the earlier list off, and its results are the first entry under Done.

- `relay start` over a long session, and its stop for a stale copy. It ran for real once, on 2026-11-06 at 0.2.5, and the user reported four things: Cowork read the note and asked "What are you working on?" with no menu, its steps came as the short YOUR TURN block with one command each, two scans in a row were both on the clipboard, and a second `relay start` had nothing to wait for. Not known: whether the block holds late in a long session, whether Cowork stops when its copy is stale, which that run had no reason to show, and whether people run it each session.
- Remembered clones, since 0.2.6. Smoke tests only.
- The practice round, with real Cowork. Smoke tests only. Not known: whether Cowork keeps it to four steps and about ten minutes, and whether it writes a sensible deliverable for a one-line change.
- The kept answer to the secrets question, on real repositories. Smoke tests only. Not known: whether asking once is the right balance, and whether people notice the line that says the places are the same as before.
- A skill copy that a terminal app can't read. The tests take the file's permission away, which isn't the refusal macOS gives. Whether that refusal was behind the wrong "made by hand" on 2026-11-06 isn't confirmed.
- The secrets check, on ordinary code. It ran once for real, on 2026-11-06 at 0.2.4, on the deployment folder whose scan had carried credentials: it listed 52 places, the user pressed `n`, and nothing was sent. Not known: how often it flags something harmless in a repository that holds no secrets, what it misses, and whether people read the list or press `y`.
- A scan sent under a longer name, and Cowork reading it. The same run named the deployment folder's scan with its parent folder in front, because the code repository's scan already had the plain name. It was never sent.
- A bare `!N` that repeats a merge request linked in another project, since 0.2.4. Smoke tests only.
- The checks in `relay mr`, with real Cowork. The field test's merge request was in a Python repository, and the checks are for Go only, so none ran.
- Proving a review's finding with a run. Two runs in the field test never reached the code, because the Mac had no way to run that repository's tests outside a Docker image that wasn't built. `safe_worktree` left the checkout alone both times.
- Waking Cowork. The user's Teams had no Workflows app, so no webhook could be made. An email trigger worked on 2026-11-03, and hasn't been tried with the relay.
- Anything with Jira or Confluence. Cowork couldn't read a ticket or its page by any route. The Mac has `jira` and `acli`, and the relay doesn't use them yet.
- A run from a terminal app other than Apple's Terminal. The relay's refusal message has only run against an imitation. Why iTerm was refused once, and not later, is unknown.
- Cowork's review findings against a Claude review of the same merge request. Never compared.
- Attempts on real code. The field test's two attempts were planted. Not known: whether Cowork writes real alternatives or pads a deliverable, and how long several builds take in one run.
- Whether Cowork follows what a repository's wiki says. The wiki reached it with a scan and with a merge request in the field test, and the review listed it. Nothing showed a page changing what Cowork did.
- The guided test's skill as reworded in 0.2.3: the count of skills in place of their names, the dated report name, and the order of the screenshot and the keys.
- `relay field-test --clean` run from inside the test repository, since 0.2.3. Smoke tests only.

## Done

### A practice round, and a secrets question that isn't asked every time (2026-11-06)

- **Why the practice round:** a new person's first `y` was on their own code. `relay start` had its first real run that day and held, which the practice round was waiting on.
- **What changed:** `relay practice` makes a small repository at `~/relay-practice` and hands Cowork a prompt, as `relay start` does. The skill has a section for it: Cowork adds a line of its own to a file there, the user runs it and applies it, sees the line on their Mac, and cleans up. `relay practice --clean` removes the repository.
- **Why the secrets question changed:** a count over the clones on two Macs put the check at about three repositories in ten, mostly for lines in deployment settings. Asked that often, people stop reading and press `y`.
- **What changed:** a yes is kept for a repository, with a mark of what was found by file, kind and number. The question comes back only when that changes. `--ask` on `relay scan` and `relay mr` asks again. The kept answer is used only at a terminal, so with none the relay still refuses. This is 0.2.7.

### The relay remembers where a clone is (2026-11-06)

- **Why:** `relay mr` looked only under the folders in the `clones` setting. A clone kept anywhere else needed `--repo` on every review.
- **What changed:** naming a clone once with `--repo` is enough. The relay keeps where each project's clone is, beside its settings, and looks there before it searches. A clone it finds by searching is kept the same way, so the search is paid once. A remembered folder that has gone is ignored. This is 0.2.6.

### One command to begin with (2026-11-06)

- **Why:** the relay is now for a whole team. A new person had to know which command starts each thing, what to tell Cowork after it, to run setup again after an upgrade and wait, and that a review needs `glab`, which they found out when one failed.
- **What changed:** `relay start` gets Cowork this relay's skills, replacing an older relay's, says what the Mac is set up for and what a missing tool needs, and puts a prompt on the clipboard. Cowork reads a note with no paths in it, checks its copy of the skill against it, asks "What are you working on?", and gives each step in one short block. `relay scan` puts its line on the clipboard, and scans close together add up. `relay setup` prints the same list and points at `relay start`. `relay mr` says how to get a tool it lacks. This is 0.2.5, and `design-and-decisions/guided.md` has the design.
- **Also:** a skill copy that a terminal app can't read was reported as made by hand. It is now its own state, said plainly, and left alone.
- **Not built:** the practice round, and a plain summary of a deliverable before `y`.

### The relay looks for secrets before it sends code (2026-11-06)

- **Why:** in a real review on 2026-11-06, Cowork asked for a deployment repository, and its scan carried production credentials in plain text to OneDrive. The relay sent whatever was committed, with no check. Cowork noticed and didn't repeat them.
- **What changed:** `relay scan` and `relay mr`, with every `--also`, look in what they're about to send for private keys, access tokens, lines in settings files that set a password or key, and files named like keys or credentials. If any are found, the relay lists where, without printing them, and asks at the terminal before it sends. With no terminal it refuses. No flag skips it. The note says what the check found. The skill tells Cowork never to repeat a credential, and to ask for a deployment repository only when it's needed.
- **What it doesn't do:** it goes by shape, and it reads the files at one commit. The history goes too, unchecked. Go modules and wiki pages aren't checked.
- **Also in 0.2.4:** two repositories with the same folder name no longer replace each other's scans. The same session lost a scan that way twice. And `relay mr` on that session's merge request read the linked one from the right project, which is the 0.2.2 fix working for real, but also fetched this project's own merge request of that number, because the description named it a second time in plain words. A bare number that repeats a linked one is now read as the same one, and the note says so.

### The short re-test, and what it found (2026-11-06)

- **What ran:** check 0 and part B of the guided test on the work Mac at 0.2.2, about 20 minutes. Everything passed, with nothing killed or refused. `relay apply` named the attempt that passed and applied its patch, which is the fix from 0.2.2 working for real.
- **Fixed in 0.2.3:** the test's skill asked Cowork to list the skills in its folder, and skills can be named after people, so names reached a report that is meant to hold none. It now asks for a count, and rule 8 says a name can sit inside another name. Each test's report is saved under its date, so one test no longer replaces the last. `relay field-test --clean` says to run `cd ~` when it has removed the folder the terminal was in, and the skill's step starts with `cd ~`. The skill asks for the screenshot before the keys, in that order. `relay run` says which terminal app it's in on its first line.
- **Also in the skills:** wait for the manifest command before publishing, since a deliverable went out without one. `safe_worktree` is for runs that change no tracked file. The first publish of a new folder has taken up to two minutes to reach the Mac.
- **Seen, and left:** the first run waited 110 seconds for a manifest that Cowork's side already showed. The relay waited as it should.

### The field test, and what it found (2026-11-06)

- **What ran:** Cowork led the guided test on the work Mac at 0.2.1, in Apple's Terminal, with nothing attached and no Always Keep. That was 7 runs, 2 applies, 1 review and 4 scans, with no refusal and no `killed`. About 30 YOUR TURN blocks worked the first time, and 3 needed a second ask.
- **What passed:** a scan read with its hash checked, a run from a fresh publish, a planted failure and then its fix, `n` sending nothing, `relay apply`, a scan of another branch, a review saved with its Coverage shown, `safe_worktree`, your own skill copied with its stamp cited, the check that a copy has fallen behind, the prompt typed by hand with `v` opening a pager, and a 59.7 MB file. A Go module with 541 lines of vendored modules built and vetted in Cowork's sandbox, offline.
- **Fixed in 0.2.2:** `relay apply` refused a run with attempts that had passed, because it took the last report in the task's folder by name, and a task's deliverables share that folder. `relay run` now records which report came from which files, on the Mac, and `relay apply` reads that. `relay mr` fetched this project's merge request of the same number when the description linked one in another project. It now fetches each from its own project, and the note says which file holds which. The message for a skill you made by hand says your own text goes over whatever you choose. A scan of another branch says in its note that uncommitted changes were left out. A run with attempts says its `checks:` line leaves the attempts' checks out, so `runlib.sh` is version 6. The guided test's note says where a skill stands in plain words. Both skills have the wording fixes the test's report asked for.
- **Found, and not fixed:** the checks in `relay mr` are for Go only. Cowork's download tool keeps the first copy of a file it has read, so a second scan of a repository needed a way round, which the skill now gives. Teams had no Workflows app, so the wake-up couldn't be tried. Cowork can't reach Jira or Confluence.

### The guided test asks in a way that can't be missed (2026-11-05)

- **Why:** the first guided tests worked because of rules written from what the user had missed: things buried in a message, a screenshot asked for after the moment, a pop-up answer left out. The first version of the skill kept the evidence rules and dropped those.
- **What changed:** the skill's YOUR TURN block now has DO THIS NOW, WATCH FOR, SCREENSHOT, DON'T and THEN TELL ME, with standing watch items on every `relay` command. Cowork stops at the start if its copy of a skill is stale. Claims are labelled OBSERVED, USER REPORTED, INFERRED, NOT TESTED or UNKNOWN, and the report is judged against 18 criteria fixed in the skill. `relay field-test` makes its own repository at `~/relay-field-test`, and `--clean` removes it. This is 0.2.1.

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
