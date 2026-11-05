# AGENTS.md

`relay` is the Mac's side of a bridge that lets Microsoft Copilot Cowork change code through runs on the user's machine, over OneDrive. `README.md` says what it's for, and `docs/using.md` how it works.

- `relay.sh`: the command. Link it onto the PATH as `relay`.
- `cowork/remote-pair-run/`: the skill `relay setup` copies to OneDrive. `SKILL.md` is what Cowork reads, and `runlib.sh` runs on both sides.
- `tests/smoke.sh`: runs against a fake OneDrive, `glab` and `wiki`.

Rules:

- Keep it working on Apple's bash 3.2. Never feed a loop with process substitution: use a heredoc. A smoke test checks.
- Run `tests/smoke.sh` and `shellcheck -S warning relay.sh cowork/remote-pair-run/runlib.sh tests/smoke.sh` before any commit, and add a test for what you changed.
- Work on a branch, and merge when CI is green.
- Nothing from the cloud runs or lands until the user presses a key here. `relay run`, `review` and `apply` need a terminal, and there's no flag to skip that. Don't add one.
- Dependencies point one way. The relay may call `wiki which [repository]`, and has to work with no `wiki` command. llm-wiki doesn't know about the relay.
- Don't claim a change works with Cowork or OneDrive because the smoke tests pass. They use fakes. Say what ran for real, and keep `ROADMAP.md`'s Untested list current.
- A skill change only reaches Cowork after `relay setup`, and its copy can lag by several minutes.
