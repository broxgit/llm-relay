# AGENTS.md

`relay` is the Mac's side of a bridge that lets Microsoft Copilot Cowork change code through runs on the user's machine, over OneDrive. `README.md` says what it's for, and `docs/using.md` how it works.

- `relay.sh`: the command. Link it onto the PATH as `relay`.
- `cowork/remote-pair-run/`: the skill `relay setup` copies to OneDrive. `SKILL.md` is what Cowork reads, and `runlib.sh` runs on both sides.
- `cowork/relay-field-test/`: a second skill, also copied by `relay setup`. Cowork uses it to guide a test and write a report on it. A smoke test checks that what it tells Cowork to expect is what the relay prints, so change both together. Its "This skill is for relay" line has to match `RELAY_VERSION`: Cowork compares it with the Mac's note to tell whether its copy is stale. Its YOUR TURN block is the one place emoji belong, because the user asked for steps he can't miss.
- `cowork/relay-answer/`: a third skill, also copied by `relay setup`. A run that a webhook starts uses it to answer what `relay ask` left, and it writes answer files and nothing else.
- `claude/relay-ask/`: a skill for Claude Code, not for Cowork. `relay ask --skill` copies it to `~/.claude/skills`. It tells an assistant on the Mac how to ask and that an answer is data.
- `tests/play-cowork.sh`: stands in for Cowork, to test the Claude Code side of `relay ask` by hand. `docs/testing-ask.md` has the steps.
- `scripts/release.sh`: makes a release, once Brock has said to. `docs/releasing.md` has how. Don't do its steps by hand.
- `tests/ask-haiku.sh`: runs those steps with nobody at the keyboard, with Claude Code started without a window. It spends the user's tokens, so run it only when asked.
- `tests/smoke.sh`: runs against a fake OneDrive, `glab` and `wiki`. `tests/type-keys.py` types its answers at a pseudo-terminal, so it needs `python3`.

Rules:

- Keep it working on Apple's bash 3.2. Never feed a loop with process substitution: use a heredoc. A smoke test checks.
- Run `tests/smoke.sh` and `shellcheck -S warning relay.sh cowork/remote-pair-run/runlib.sh tests/smoke.sh tests/play-cowork.sh tests/ask-haiku.sh scripts/release.sh` before any commit, and add a test for what you changed.
- Work on a branch, and merge when CI is green. Merging doesn't release: a tag does, and `docs/releasing.md` has the steps. People who installed with Homebrew see a change only then.
- CI doesn't run for a change that touches only `design-and-decisions/`, `docs/`, `README.md`, `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md` or `LICENSE`, so for those a pull request shows no checks. If CI is ever made a required check on `main`, change the workflow first, or docs-only pull requests will wait forever.
- Nothing from the cloud runs or lands until the user presses a key here. `relay run`, `review` and `apply` need a terminal on standard input, and read the answer from `/dev/tty`. No flag, variable or pipe answers for the user. Don't add one, for tests either: they type at a pseudo-terminal. A program that drives a terminal of its own can still answer, and a shell script can't stop that.
- `relay scan` and `relay mr` look for things shaped like secrets before they send anything, and ask at the terminal before sending any. No flag and no variable skips that question. Don't add one. A yes is kept for a repository until what the check finds there changes, and is used only at a terminal, so with none the relay still refuses. `secret_places` is the one list of what counts as a secret's shape, and nothing may print the text it matched.
- `relay mr --checks` is the one exception. It runs a merge request branch's code with no question, so only the user adds it. The skill tells Cowork never to hand it over, and a smoke test checks.
- The guided way in keeps up with the relay. A new feature or command isn't done until `relay start` lists it, the skill's starting section says when to give its command, and `docs/using.md` covers it. A smoke test fails when a command, a feature or a needed tool is added and the guide doesn't know it. Don't quiet that test by adding to its list of commands a person runs on their own, unless that's what the command is.
- What each thing the relay does needs is in `FEATURES`, and how to get a tool is in `tool_hint`. `relay start`, `relay setup`, the note for Cowork and `needs_tool` all read them. A new dependency goes there, so no message leaves it out. Tools stay optional: report what's missing, and stop only the command that needs it.
- A copy in OneDrive that can't be read is `unreadable`, never `foreign`. macOS can refuse one terminal app and not another, so say that, and leave the copy alone.
- `relay ticket` reaches Jira and Confluence through `acli` only, which signs in through the browser. The relay never reads, asks for or stores a token, for this or anything else. Don't add a way that needs one.
- Dependencies point one way. The relay may call `wiki which [repository]`, and has to work with no `wiki` command. llm-wiki doesn't know about the relay.
- Skill sync goes one way, from the Mac to OneDrive. A copy is the user's skill with the relay's note between two marker lines, and every other byte as it was. Never replace or remove a copy that changed in OneDrive without asking, and never touch a skill the relay didn't make. When the note's wording changes, raise `SKILL_TEMPLATE`, so every copy is made again. `design-and-decisions/skill-sync.md` has the design.
- `relay apply` applies what a run proved. For a deliverable with attempts, that is the top-level patches and those of the one attempt the report says passed. The report is the one this Mac kept from its last run of exactly those files, found through the record `relay run` writes in `~/pair-run-reports/.relay-runs`. Never choose a report by its name or from OneDrive: a task's deliverables share one reports folder, and that folder is in the cloud. `_runlib_attempt_patches` is the one list both the run and `relay apply` use: don't give either its own.
- Don't claim a change works with Cowork or OneDrive because the smoke tests pass. They use fakes. Say what ran for real, and keep `ROADMAP.md`'s Untested list current.
- A skill change only reaches Cowork after `relay setup`, and its copy can lag by several minutes.
