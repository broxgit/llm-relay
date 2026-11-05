# AGENTS.md

`relay` is the Mac's side of a bridge that lets Microsoft Copilot Cowork change code through runs on the user's machine, over OneDrive. `README.md` says what it's for, and `docs/using.md` how it works.

- `relay.sh`: the command. Link it onto the PATH as `relay`.
- `cowork/remote-pair-run/`: the skill `relay setup` copies to OneDrive. `SKILL.md` is what Cowork reads, and `runlib.sh` runs on both sides.
- `cowork/relay-field-test/`: a second skill, also copied by `relay setup`. Cowork uses it to guide a test and write a report on it. A smoke test checks that what it tells Cowork to expect is what the relay prints, so change both together.
- `tests/smoke.sh`: runs against a fake OneDrive, `glab` and `wiki`. `tests/type-keys.py` types its answers at a pseudo-terminal, so it needs `python3`.

Rules:

- Keep it working on Apple's bash 3.2. Never feed a loop with process substitution: use a heredoc. A smoke test checks.
- Run `tests/smoke.sh` and `shellcheck -S warning relay.sh cowork/remote-pair-run/runlib.sh tests/smoke.sh` before any commit, and add a test for what you changed.
- Work on a branch, and merge when CI is green. Merging doesn't release: a tag does, and `docs/releasing.md` has the steps. People who installed with Homebrew see a change only then.
- CI doesn't run for a change that touches only `design-and-decisions/`, `docs/`, `README.md`, `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md` or `LICENSE`, so for those a pull request shows no checks. If CI is ever made a required check on `main`, change the workflow first, or docs-only pull requests will wait forever.
- Nothing from the cloud runs or lands until the user presses a key here. `relay run`, `review` and `apply` need a terminal on standard input, and read the answer from `/dev/tty`. No flag, variable or pipe answers for the user. Don't add one, for tests either: they type at a pseudo-terminal. A program that drives a terminal of its own can still answer, and a shell script can't stop that.
- `relay mr --checks` is the one exception. It runs a merge request branch's code with no question, so only the user adds it. The skill tells Cowork never to hand it over, and a smoke test checks.
- Dependencies point one way. The relay may call `wiki which [repository]`, and has to work with no `wiki` command. llm-wiki doesn't know about the relay.
- Skill sync goes one way, from the Mac to OneDrive. A copy is the user's skill with the relay's note between two marker lines, and every other byte as it was. Never replace or remove a copy that changed in OneDrive without asking, and never touch a skill the relay didn't make. When the note's wording changes, raise `SKILL_TEMPLATE`, so every copy is made again. `design-and-decisions/skill-sync.md` has the design.
- `relay apply` applies what a run proved. For a deliverable with attempts, that is the top-level patches and those of the one attempt the report says passed, and only when the report in OneDrive is the same file this Mac kept. `_runlib_attempt_patches` is the one list both the run and `relay apply` use: don't give either its own.
- Don't claim a change works with Cowork or OneDrive because the smoke tests pass. They use fakes. Say what ran for real, and keep `ROADMAP.md`'s Untested list current.
- A skill change only reaches Cowork after `relay setup`, and its copy can lag by several minutes.
