#!/usr/bin/env bash
# Makes a release of llm-relay: the steps of docs/releasing.md, in one command.
#
#   scripts/release.sh VERSION NOTES-FILE [--dry-run]
#
# It releases the commit that main is at, and only if that commit is what GitHub has, the five
# version lines say VERSION, and CI passed on it. Then it makes the release, points the
# Homebrew formula at it, and checks the formula the way a user gets it. --dry-run stops before
# anything is made. Run again after a failure, it skips what is already done.
#
# It decides nothing: whether to release, and what the notes say, are settled before it runs.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLUG="broxgit/llm-relay"
FORMULA="Formula/llm-relay.rb"
# The files CI doesn't run for. .github/workflows/ci.yml has the same list.
DOCS_ONLY='^(design-and-decisions/|docs/|README\.md$|ROADMAP\.md$|AGENTS\.md$|CLAUDE\.md$|LICENSE$)'

die() { echo "release: $*" >&2; exit 1; }
step() { echo "== $*"; }

version="" notes="" check=""
for a in "$@"; do
  case "$a" in
    # --dry-run is the name docs/conventions.md gives it. --check is the old one.
    --dry-run | --check) check=1 ;;
    -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $a" ;;
    *) if [ -z "$version" ]; then version="$a"; elif [ -z "$notes" ]; then notes="$a"; else die "too many arguments"; fi ;;
  esac
done
[ -n "$version" ] && [ -n "$notes" ] || die "usage: scripts/release.sh VERSION NOTES-FILE [--dry-run]"
printf '%s\n' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "a version looks like 0.2.18, with no v in front: $version"
[ -s "$notes" ] || die "no release notes at $notes"
tag="v$version"

step "The five version lines"
wrong=""
grep -q "^RELAY_VERSION=\"$version\"\$" "$REPO/relay.sh" || wrong="$wrong relay.sh"
for f in cowork/remote-pair-run cowork/relay-field-test cowork/relay-answer claude/relay-ask; do
  grep -q "This skill is for relay $version\\." "$REPO/$f/SKILL.md" || wrong="$wrong $f/SKILL.md"
done
[ -z "$wrong" ] || die "these don't say $version:$wrong. The version is raised on a branch, with the change it releases."
echo "all say $version"

step "The commit"
for t in git gh curl shasum; do command -v "$t" >/dev/null 2>&1 || die "needs $t"; done
[ "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
[ -z "$(git -C "$REPO" status --porcelain --untracked-files=no)" ] || die "main has changes that aren't committed"
git -C "$REPO" fetch -q origin main || die "couldn't fetch origin"
sha="$(git -C "$REPO" rev-parse HEAD)"
[ "$sha" = "$(git -C "$REPO" rev-parse origin/main)" ] || die "main here isn't what GitHub has. Pull or push first."
echo "main is at $(git -C "$REPO" log --oneline -1)"

step "CI"
# CI doesn't run for a commit that only changes documents, so the run to trust is the newest
# one on main, as long as everything since it is documents.
newest_run() { gh run list -R "$SLUG" --branch main --workflow CI --limit 1 --json databaseId,headSha,status --jq '.[0] | "\(.databaseId) \(.headSha) \(.status)"'; }
waited=0
while :; do
  run="$(newest_run)" || die "couldn't ask GitHub about CI"
  [ -n "$run" ] || die "no CI run on main"
  # shellcheck disable=SC2086
  set -- $run
  run_id="$1" run_sha="$2" run_status="$3"
  [ "$run_sha" != "$sha" ] || break
  git -C "$REPO" merge-base --is-ancestor "$run_sha" "$sha" 2>/dev/null || die "the newest CI run is for $run_sha, which isn't part of main here"
  since="$(git -C "$REPO" diff --name-only "$run_sha" "$sha" | grep -vE "$DOCS_ONLY" || true)"
  if [ -z "$since" ]; then
    echo "the newest run is for ${run_sha:0:7}, and only documents have changed since"
    break
  fi
  # Just after a merge, GitHub takes a moment to start the run for it.
  [ "$waited" -lt 120 ] || die "CI hasn't started on this commit after ${waited}s. These changed since its last run: $(echo "$since" | tr '\n' ' ')"
  [ "$waited" -gt 0 ] || echo "no run for this commit yet, so this waits up to two minutes for one to start"
  sleep 10
  waited=$((waited + 10))
done
waited=0
while [ "$run_status" != completed ]; do
  [ "$waited" -lt 1800 ] || die "CI run $run_id is still going after 30 minutes. Run this again when it ends."
  if [ $((waited % 60)) = 0 ]; then echo "run $run_id is $run_status, ${waited}s so far. It takes about seven minutes."; fi
  sleep 20
  waited=$((waited + 20))
  run_status="$(gh run view "$run_id" -R "$SLUG" --json status --jq .status)" || die "couldn't ask GitHub about run $run_id"
done
[ "$(gh run view "$run_id" -R "$SLUG" --json conclusion --jq .conclusion)" = success ] || die "CI run $run_id didn't pass. Fix main first."
echo "run $run_id passed"

if [ -n "$check" ]; then
  echo "== Checked. Nothing was made, because of --dry-run."
  exit 0
fi

step "The release"
if gh release view "$tag" -R "$SLUG" >/dev/null 2>&1; then
  echo "$tag is already released, so this goes on from there"
else
  gh release create "$tag" -R "$SLUG" --target "$sha" --title "llm-relay $version" --notes-file "$notes" || die "couldn't make the release"
fi

step "The archive's hash"
url="https://github.com/$SLUG/archive/refs/tags/$tag.tar.gz"
hash="" n=0
while [ -z "$hash" ] && [ "$n" -lt 6 ]; do
  hash="$(curl -fsSL "$url" | shasum -a 256 | awk '{ print $1 }')"
  # The hash of nothing: the archive wasn't there yet.
  [ "$hash" != e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ] || hash=""
  [ -n "$hash" ] || { n=$((n + 1)); sleep 5; }
done
[ -n "$hash" ] || die "couldn't download $url. The release is made. Run this again for the rest."
echo "$hash"

step "The Homebrew formula"
# A clone of the same form as this repository's origin, since a plain https clone can't push.
tap_url="$(git -C "$REPO" remote get-url origin | sed 's#llm-relay\(\.git\)\{0,1\}$#homebrew-tap\1#')"
tap="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay-tap.XXXXXX")" || die "can't make a scratch folder"
trap 'rm -rf "$tap"' EXIT
git clone -q "$tap_url" "$tap/tap" || die "couldn't clone the tap from $tap_url. The release is made. Run this again for the rest."
sed -i.bak -e "s#refs/tags/v[0-9.]*\\.tar\\.gz#refs/tags/$tag.tar.gz#" -e "s#sha256 \"[0-9a-f]*\"#sha256 \"$hash\"#" "$tap/tap/$FORMULA" || die "couldn't edit the formula"
rm -f "$tap/tap/$FORMULA.bak"
grep -q "refs/tags/$tag.tar.gz" "$tap/tap/$FORMULA" && grep -q "sha256 \"$hash\"" "$tap/tap/$FORMULA" || die "the formula doesn't have the new address and hash, so it wasn't pushed"
if [ -z "$(git -C "$tap/tap" status --porcelain)" ]; then
  echo "the formula already points at $tag"
else
  msg="llm-relay $version"
  # RELEASE_TRAILER: a last line for the commit, such as a co-author.
  [ -z "${RELEASE_TRAILER:-}" ] || msg="$msg

$RELEASE_TRAILER"
  git -C "$tap/tap" commit -q -m "$msg" -- "$FORMULA" || die "couldn't commit the formula"
  git -C "$tap/tap" push -q origin HEAD || die "couldn't push the formula. The release is made. Run this again for the rest."
  echo "pushed: $(git -C "$tap/tap" log --oneline -1)"
fi

step "The way a user gets it"
if ! command -v brew >/dev/null 2>&1; then
  echo "no brew on this machine, so the formula wasn't tried"
  echo "== Released $tag. Not checked with Homebrew."
  exit 0
fi
brew update >/dev/null 2>&1 || die "brew update failed"
if brew list llm-relay >/dev/null 2>&1; then
  brew upgrade llm-relay >/dev/null 2>&1 || true
else
  brew install broxgit/tap/llm-relay >/dev/null 2>&1 || die "brew couldn't install it"
fi
got="$("$(brew --prefix)/bin/relay" --version 2>/dev/null)"
[ "$got" = "relay $version" ] || die "brew has \"$got\", not relay $version"
echo "$got"
brew test llm-relay >/dev/null 2>&1 || die "brew test failed"
echo "brew test passed"
brew audit --strict llm-relay >/dev/null 2>&1 || die "brew audit --strict found something. Run it to see."
echo "brew audit --strict is clean"

echo "== Released $tag: https://github.com/$SLUG/releases/tag/$tag"
