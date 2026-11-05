# Releasing

A release is a tag on `main`. Merging to `main` doesn't release anything: people who installed with Homebrew get a change only when a release is made and the formula points at it.

The formula is in a second repository, [broxgit/homebrew-tap](https://github.com/broxgit/homebrew-tap), at `Formula/llm-relay.rb`.

## Make a release

1. On a branch, change `RELAY_VERSION` in `relay.sh` to the new version. Move what changed into `ROADMAP.md`'s Done section if it isn't there. Merge it when CI is green.

2. On `main`, with that merged, tag it and make the release. Use the same number, with a `v` in front.

   ```bash
   git switch main && git pull --ff-only && ./relay.sh --version
   ```

   ```bash
   gh release create v<version> --target main --generate-notes
   ```

3. Get the hash of the release's source.

   ```bash
   curl -fsSL https://github.com/broxgit/llm-relay/archive/refs/tags/v<version>.tar.gz | shasum -a 256
   ```

4. In the tap, set `url` to that address and `sha256` to that hash in `Formula/llm-relay.rb`, then commit and push.

5. Check it the way a user gets it.

   ```bash
   brew update && brew upgrade llm-relay && relay --version
   ```

   ```bash
   brew test llm-relay
   ```

## What a version number means

Before 1.0, nothing here has been proven with Copilot Cowork end to end, and any release may change a command. Raise the middle number for a new command or a change someone has to act on, such as running `relay setup` again. Raise the last for a fix.

## What an upgrade doesn't do

It doesn't touch OneDrive. The skill Cowork reads is copied there by `relay setup`. So after an upgrade the relay says, on the next `relay scan` or `relay mr`, that Cowork's copy isn't its own, until `relay setup` runs again.
