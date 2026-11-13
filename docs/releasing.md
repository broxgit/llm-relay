# Releasing

A release is a tag on `main`. Merging to `main` doesn't release anything: people who installed with Homebrew get a change only when a release is made and the formula points at it.

The formula is in a second repository, [broxgit/homebrew-tap](https://github.com/broxgit/homebrew-tap), at `Formula/llm-relay.rb`.

## Make a release

1. On a branch, change `RELAY_VERSION` in `relay.sh` to the new version, and the "This skill is for relay" line in each skill to match: `cowork/relay-field-test/SKILL.md`, `cowork/remote-pair-run/SKILL.md`, `cowork/relay-answer/SKILL.md` and `claude/relay-ask/SKILL.md`. A smoke test fails if any of the five differ. Move what changed into `ROADMAP.md`'s Done section if it isn't there. Merge it when CI is green.

2. Write the release notes, for the person upgrading: what is new, what changed, what hasn't been tried, and how to update. They go in `releases/latest`, in a file named for the release, such as `release-0.2.25.md`. Move the file that is there to `releases/archive` first: `releases/latest` holds one file, the next release's. Neither folder is in git.

3. With that merged, run the script. It takes nothing:

   ```bash
   scripts/release.sh
   ```

   It does the rest, and says each step as it goes:

   - **It reads the version from the name of the notes file.**
   - **It switches to `main` and pulls,** unless the checkout has changes that aren't committed.
   - **It refuses unless** the five version lines say that version, and CI passed. A commit that only changes documents has no CI run, so it takes the newest run on `main` when only documents have changed since. It waits for a run that is still going.
   - **It makes the release** at that commit, with a `v` in front of the number.
   - **It points the formula at it:** the address and the hash of the release's source, in a fresh clone of the tap, committed and pushed.
   - **It checks it the way a user gets it:** `brew update`, `brew upgrade`, `relay --version`, `brew test` and `brew audit --strict`.
   - **It adds a line to `releases/log.md`,** and commits and pushes that one file to `main`.

   `--dry-run` stops before anything is made or changed, the checkout included. If a step fails after the release is made, run the same command again: it skips what is done.

   If CI never starts, GitHub may have lost the run. That happened on 2026-11-11, when an outage left a run queued that could be neither cancelled nor run again. Start a new one by hand, then run the script again:

   ```bash
   gh workflow run CI --ref main
   ```

   The script decides nothing. Whether to release is Brock's call each time, and the notes are written before it runs.

   The older way still works, with the version and a notes file named: `scripts/release.sh <version> <notes-file>`.

## What a version number means

Before 1.0, nothing here has been proven with Copilot Cowork end to end, and any release may change a command.

Raise the last number for a release, whatever is in it. Raise the middle number only when Brock says a release is a step change. 1.0.0 is his decision, made when the relay has been proven with Copilot Cowork end to end. The numbers don't get there by counting.

## What an upgrade doesn't do

It doesn't touch OneDrive. The skill Copilot Cowork reads is copied there by `relay setup`. So after an upgrade the relay says, on the next `relay scan` or `relay mr`, that Copilot Cowork's copy isn't its own, until `relay setup` runs again.

A user who runs `brew upgrade` without `brew update` first may be told the old version is already installed. So every place that tells users how to update gives both.
