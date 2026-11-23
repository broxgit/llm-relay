# llm-relay review (2026-11-07)

Reviewed against `0.2.11` (`1fc20c9`).

## 1. What needs fixing

1. **`relay branch` tells Cowork the wrong path for check results (`mr/checks/` instead of `branch/checks/`).**
   In `cmd_branch` (`relay.sh:2436-2440`), `CHECKS_DIR` is set to `"$WORK/branch/checks"`, and the archive packs `branch/`. However, `run_checks` (`relay.sh:1464`) hardcodes:
   ```bash
   CHECKS_LINE="$CHECKS_RUN run, $CHECKS_BAD failed or stopped, in mr/checks/summary.txt"
   ```
   As a result, the `LLM-RELAY BRANCH` note points Cowork to `mr/checks/summary.txt`, which does not exist in a branch archive (`cowork/remote-pair-run/SKILL.md:412` tells Cowork to read `branch/checks/`). Similarly, `plan_checks` (`relay.sh:1292`) and `run_checks` (`relay.sh:1447-1448`) say `"the files the merge request changes"` even when called from `relay branch`. Using `${CHECKS_DIR#"$WORK/"}/summary.txt` fixes the path.

2. **`secret_places_uncommitted` double-counts an existing finding when uncommitted edits shift line numbers, invalidating the remembered `y`.**
   In `secret_places_uncommitted` (`relay.sh:679-693`), `$known` holds `<file>:<line>: <kind>` from `HEAD`, and `$line` holds `<file>:<line>: <kind>` from the working tree on disk. If a file has a known secret-shaped config line at line 50 and your uncommitted changes add an import at the top of that file, the working-tree match moves to line 51. `grep -Fxq -- "$line" "$known"` (`relay.sh:689`) misses because `51 != 50`, so it appends `<file>:51: <kind>, in your uncommitted changes`. Then `secrets_mark` (`relay.sh:705-708`) strips line numbers and hashes the list, which now has two entries for the same line (`<kind>` and `<kind>, in your uncommitted changes`), changing the mark hash and re-prompting you even though no secret changed.

3. **`relay branch` does not send internal Go modules, unlike `relay mr`.**
   Stage 5 in `cowork/remote-pair-run/SKILL.md:122` tells you to run `relay branch` and paste its prompt into a new Cowork session so the session that wrote the code is not reviewing its own work. `pack_mr` (`relay.sh:1606`) calls `collect_modules` (`relay.sh:1183-1233`) so the reviewer can read the pinned internal Go libraries in `go-modules/`, whereas `cmd_branch` (`relay.sh:2324-2495`) skips `collect_modules`. Calling `collect_modules` in `cmd_branch` gives pre-MR branch reviews the same library context as MR reviews.

4. **`warn_if_moved` in `relay review` only checks merge requests, not branch reviews.**
   `warn_if_moved` (`relay.sh:1796-1807`) looks only in `$COWORK/relay/mrs/${f##*/}.txt`. When `relay review` saves a review from `relay branch` (whose note lives in `$COWORK/relay/branches/`), it does not warn if you made local commits on the branch after packing it.

5. **Small CLI and documentation drift:**
   - `usage()` (`relay.sh:97`) omits `[--plans FOLDER]` and `[--skills-from FOLDER]` on the `relay setup` synopsis line (though `relay setup --help` includes them).
   - `cmd_field_test` (`relay.sh:3237`) checks `for key in reviews clones` and leaves out `plans`.
   - The header comment at the top of `relay.sh` (`relay.sh:4-11`) lists 8 commands, omitting `start`, `practice`, `ticket`, and `branch`.
   - `design-and-decisions/leverage.md` (`leverage.md:3,75`) still says steps 4 and 6 are unbuilt/untried, though `relay ticket` shipped in `0.2.9` and the 2026-11-06 field test proved offline Go builds with vendored dependencies.

---

## 2. Features to add next

Ordered by how much friction or Claude token burn each one removes:

1. **Auto-vendor or pack Go dependencies in `relay scan --vendor` (or `relay go-pack`)**
   - **Why:** The 2026-11-06 field test proved that Cowork's sandbox built, vetted, and ran `go test` offline against a 541-line `vendor/` tree with `GOFLAGS=-mod=vendor GOPROXY=off GOTOOLCHAIN=local`. Repositories that do not commit a `vendor/` directory cannot compile or run unit tests inside Cowork's sandbox today, so every syntax or type error costs a Mac round-trip.
   - **How:** Add a flag (or auto-detect when `go.mod` is present and `vendor/` is not) in `relay scan` / `relay branch` that runs `go mod vendor` in a temporary worktree or packs the needed module cache slice into the scan archive, plus caches the Linux `go*.linux-amd64.tar.gz` tarball in `Documents/Cowork/relay/toolchains/` once so you never have to upload it by hand.
   - **Trade-off:** Larger scan archives (typically 5 to 25 MB compressed for Go dependencies), well under the 59.7 MB already proven in the field test.

2. **A plain-English diff and command summary before `Run it?` and `Apply it?`**
   - **Why:** Listed as "Not built" in `ROADMAP.md:85`. Today `show_deliverable` (`relay.sh:367-385`) lists file names and byte counts, and pressing `v` dumps raw files into `less`. Between filenames and reading raw bash and unified diffs in a pager, a short digest makes the gate much faster to judge.
   - **How:** Before prompting `Run it?` or `Apply it, uncommitted?`, print `git apply --stat` for each `.patch` file, the list of `step "..."` and `check "..."` / `attempt "..."` lines parsed out of `run.sh`, and whether `run.sh` touches anything outside `$WORKTREE` / `$RUN_TMP`. `v` still shows the full files.

3. **`relay ci <url-or-file>` (fix failing pipelines and test logs)**
   - **Why:** Use #8 in `claude-usage-at-work.md` is fixing failing builds and pipelines from Jenkins or GitLab CI output.
   - **How:** `relay ci` fetches the failed job logs from GitLab via `glab ci` (or takes a downloaded Jenkins log file), runs them through `secret_places_in` and `secrets_gate`, pairs them with a scan of the failing commit, and puts a prompt on the clipboard asking Cowork to reproduce the failure in `run.sh` before writing the fix.

4. **Email wake-up (`relay run` to Outlook / M365 trigger)**
   - **Why:** Web Teams lacked the Workflows app in the 2026-11-06 test, blocking the webhook wake-up, while the 2026-11-03 test proved an email trigger wakes the same Cowork conversation in 8 to 67 seconds even with Cowork closed.
   - **How:** Without touching tokens, test whether the work Mac can send a one-line self-email (`relay-report <task> <verdict> <version>`) via a local mail command, Shortcuts CLI (`shortcuts run`), or an Outlook rule, removing the manual `"done"` paste after every run.

5. **`relay ask` and `relay wiki-draft` (Steps 7 and 8 of the leverage plan)**
   - **Why:** Lets Claude Code hand off bulk repo-reading, unfamiliar-service onboarding, or initial wiki page drafting to Cowork's token pool, with `relay review` gating the returned markdown on a keypress and piping accepted drafts into `wiki capture`.

---

## 3. New use-cases for the Mac + Cowork split

Because Cowork has access to **Teams, Outlook email, SharePoint, and meeting transcripts** plus an **isolated Linux container** with no network, while the Mac has git history, `glab`, `acli`, and `llm-wiki`, the bridge enables workflows that neither side can do alone:

1. **Tribal Knowledge Harvester (`relay scan` + M365 search to `llm-wiki` captures)**
   When opening an unfamiliar repository or legacy service, send a `relay scan` and ask Cowork to cross-reference the codebase's module names, key packages, and recent commit subjects against your Teams chat history, emails, and SharePoint ADRs. Cowork finds the threads where coworkers explained why a workaround exists or what broke in production, and outputs citation-backed markdown notes in the deliverable that you review with `v`/`y` and feed into `wiki.sh capture`.

2. **Sprint, Standup, and Retro Compiler (`relay standup`)**
   A small Mac command packs your last `N` days of git commits across `$CLONES_DIRS`, your recent `~/mr-reviews/` filenames, and your `llm-wiki` log/journal entries (commit subjects and dates only, no code bodies) and sends that summary to OneDrive. Cowork combines your git and wiki activity with your calendar meetings, sent emails, and Teams threads from the same window to draft a weekly status update, client summary, or standup note.

3. **Post-Incident and Alert Triage Correlator**
   When an alert fires or an incident finishes, Cowork can already read the alert emails, Teams incident channel transcript, and SharePoint runbooks. Pair that with `relay scan` of the service and `relay ticket` of the incident ticket: Cowork correlates the timestamps in the Teams chat against the code paths and recent commits in the bundle, writes a root-cause timeline, and gives you a `safe_worktree` reproduction test in `run.sh` to prove the bug on your Mac.

4. **Cross-Repo Breaking-Change Audit (`relay callers`)**
   When changing a shared Go library or proto definition, a helper on the Mac greps `$CLONES_DIRS` for every repository importing that package, packs only the matching caller files (like `--also` folders), and sends them to Cowork. Cowork checks every call site across the organization against your branch and outputs a coordinated rollout plan and per-repo patches.

5. **PR Review Calibration ("Shadow Reviewer" benchmark)**
   Since `relay mr` already packs `mr/discussions-*.json` (all human and bot comments on an MR) alongside the commit history (`mr/versions.json`), you can point `relay mr` at already-merged MRs and have Cowork review `start_commit_sha` blind before reading `discussions-1.json`, then compare its findings against what human reviewers caught. That gives a zero-risk way to tune your `mr-review` skill and compare Cowork vs. Claude review quality (currently on `ROADMAP.md`'s Untested list).

6. **Automated QA and Release Test-Sheet Verifier**
   Use #5 in the Claude usage profile is writing copy-paste-ready developer and QA test instructions. With `relay`, Cowork can put the exact shell commands from the QA guide into `run.sh` inside a `safe_worktree` so that when you press `y` once, your Mac proves every copy-paste command in the QA sheet works and captures the real command output to paste into the Jira ticket or MR description.
