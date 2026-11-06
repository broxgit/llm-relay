#!/usr/bin/env bash
# runlib.sh: the shared part of every run.sh in the remote pair-run workflow. An assistant
# with no compiler or repo writes a deliverable folder; its user runs the folder's run.sh
# on a real machine and hands back the report. Works with Apple's bash 3.2.
#
# On the assistant's side, after the files are final:
#   bash runlib.sh manifest DIR [VERSION]    Hash the folder into DIR/manifest.txt. DIR needs
#                                            run.sh and runlib.sh, or a reviews/ folder.
#
# In run.sh, with no `set -e` and no `trap ... EXIT` (use on_exit):
#   . "$(dirname "${BASH_SOURCE[0]}")/runlib.sh"
#   report_start NAME "$@"       Report, header and sync check. Takes --expect N, --no-install.
#   tools go buf protoc          Print tool versions.
#   repo_state DIR...            Print branch, commit and status.
#   step TITLE                   Start a numbered step.
#   should_install               True unless --no-install was given.
#   on_exit CMD ARG...           Run at exit, last registered first, even after a crash.
#   move_aside PATH              Hide a path, as CI won't have it. Restored at exit at the latest.
#   restore_aside PATH           Put it back early.
#   safe_worktree REPO COMMIT    Make a temporary worktree with git hooks off, and set $WORKTREE.
#                                Records whether it matches the commit, whether the run changed
#                                its tracked files, and whether REPO's checkout stayed the same.
#   attempt NAME REPO COMMIT FUNC [ARG...]  Try one way of doing it: run FUNC in a fresh worktree
#                                with hooks off, as $WORKTREE. Its results are its own, so a
#                                failure doesn't fail the run. Returns 0 if it passed, so
#                                attempts chain with ||. The run passes if one attempt did.
#   apply_attempt_patches        In an attempt: apply the deliverable's own patches, then
#                                attempts/NAME/*.patch, in name order. relay apply uses the same list.
#   snapshot_tree DIR OUT [GLOB...]  Hash a tree into OUT, skipping .git and GLOBs.
#   allow_diff PATH REASON       The next compare_trees may differ here, for this reason. PATH is
#                                relative to the trees compared.
#   compare_trees LEFT RIGHT     Compare two folders or snapshots. Returns 1 on a difference.
#   check NAME CMD ARG...        Run a command and record its result.
#   expect_fail_with NAME PATTERN CMD ARG...  It must fail, and print PATTERN.
#   result NAME RC               Record RESULT NAME: PASS or FAIL.
#   abort MESSAGE                Stop now. The run fails, and the summary names the message.
#   sha256_of FILE               Print a file's SHA-256.
#   report_end                   Finish. The last line is NAME RUN: PASS or FAIL.
#
# A run passes only if it reaches report_end with at least one check and no failures.
# $RUN_TMP is a scratch folder, removed at exit.

RUNLIB_VERSION=6
RUNLIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNLIB_EXIT_COUNT=0
RUNLIB_STEP=0
RUNLIB_ENDED=""
RUNLIB_EXPECT=""
RUNLIB_NO_INSTALL=""
RUNLIB_NAME=""
RUNLIB_ATTEMPTS=0
RUNLIB_GUARDED=""
# Where results go. Inside an attempt, that's the attempt's own file.
RUNLIB_RESULTS=""
ATTEMPT=""
# shellcheck disable=SC2034  # For the run.sh that calls attempt.
ATTEMPT_DIR=""

_runlib_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | cut -d' ' -f1
  else
    shasum -a 256 <"$1" | cut -d' ' -f1
  fi
}

sha256_of() { _runlib_sha256 "$1"; }

_runlib_manifest_version() {
  sed -n '1s/^version \([0-9][0-9]*\)$/\1/p' "$1" 2>/dev/null
}

runlib_manifest() {
  local dir="${1:-}" version="${2:-}" old f tmp
  [ -d "$dir" ] || { echo "manifest: no folder: $dir" >&2; return 2; }
  # A review has nothing to run, so it needs only the review.
  if [ ! -d "$dir/reviews" ]; then
    for f in run.sh runlib.sh; do
      [ -f "$dir/$f" ] || { echo "manifest: $dir has no $f" >&2; return 2; }
    done
  fi
  if [ -z "$version" ]; then
    old="$(_runlib_manifest_version "$dir/manifest.txt")"
    version=$((${old:-0} + 1))
  fi
  case "$version" in
    '' | *[!0-9]*) echo "manifest: version must be a number: $version" >&2; return 2 ;;
  esac
  tmp="$dir/.manifest.tmp.$$"
  {
    printf 'version %s\n' "$version"
    (cd "$dir" && find . -type f ! -name manifest.txt ! -name .DS_Store ! -name '.manifest.tmp.*') |
      sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do
        printf 'sha256 %s  %s\n' "$(_runlib_sha256 "$dir/$f")" "$f"
      done
  } >"$tmp"
  # All at once, so a sync never carries half a manifest.
  mv "$tmp" "$dir/manifest.txt"
  echo "manifest: $dir/manifest.txt, version $version"
}

# Prints one line per problem. Nothing printed means the folder is what the assistant published.
_runlib_sync_problems() {
  local m="$RUNLIB_DIR/manifest.txt" version hash path need
  [ -f "$m" ] || { echo "manifest.txt is missing"; return 0; }
  version="$(_runlib_manifest_version "$m")"
  [ -n "$version" ] || { echo "manifest.txt has no version line"; return 0; }
  if [ -n "$RUNLIB_EXPECT" ] && [ "$version" != "$RUNLIB_EXPECT" ]; then
    echo "manifest.txt is version $version, expected $RUNLIB_EXPECT"
  fi
  for need in ${RUNLIB_NEEDS-run.sh runlib.sh}; do
    grep -q "^sha256 [0-9a-f]*  $need\$" "$m" || echo "manifest.txt doesn't list $need"
  done
  sed -n 's/^sha256 \([0-9a-f]*\)  \(.*\)$/\1 \2/p' "$m" | while IFS=' ' read -r hash path; do
    if [ ! -f "$RUNLIB_DIR/$path" ]; then
      echo "missing: $path"
    elif [ "$(_runlib_sha256 "$RUNLIB_DIR/$path")" != "$hash" ]; then
      echo "hash differs: $path"
    fi
  done
}

_runlib_close_report() {
  local i=0
  exec 1>&8 2>&9 8>&- 9>&-
  # A background process left holding the pipe must not hang the run.
  while kill -0 "$RUNLIB_TEE_PID" 2>/dev/null && [ "$i" -lt 30 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  kill "$RUNLIB_TEE_PID" 2>/dev/null
  wait "$RUNLIB_TEE_PID" 2>/dev/null
}

# Waits out a sync that hasn't finished. If the files changed under this run, the code in
# memory is old, so it starts again from the new files with the same arguments.
_runlib_wait_for_sync() {
  local problems waited=0 wait_for="${RUNLIB_SYNC_WAIT:-180}" poll="${RUNLIB_SYNC_POLL:-5}" count="${RUNLIB_RESYNC_COUNT:-0}"
  problems="$(_runlib_sync_problems)"
  if [ -z "$problems" ]; then
    echo "sync: version $(_runlib_manifest_version "$RUNLIB_DIR/manifest.txt"), every file matches its hash"
    return 0
  fi
  echo "sync: not ready, waiting up to ${wait_for}s:"
  printf '%s\n' "$problems" | sed 's/^/  /'
  while [ "$waited" -lt "$wait_for" ]; do
    sleep "$poll"
    waited=$((waited + poll))
    problems="$(_runlib_sync_problems)"
    [ -n "$problems" ] && continue
    [ "$count" -lt 3 ] || abort "the files keep changing during the sync"
    echo "sync: ready after ${waited}s, starting again from the new files"
    trap - EXIT
    _runlib_close_report
    rm -f "$RUNLIB_REPORT"
    rm -rf "$RUNLIB_TMP"
    export RUNLIB_RESYNC_COUNT=$((count + 1))
    # shellcheck disable=SC2093  # The lines after this loop run only if it never gets here.
    exec bash "${BASH_SOURCE[$((${#BASH_SOURCE[@]} - 1))]}" "$@"
  done
  echo "sync: still not ready after ${wait_for}s:"
  printf '%s\n' "$problems" | sed 's/^/  /'
  abort "the folder doesn't match its manifest. Wait for OneDrive, or ask for the deliverable again"
}

# Copilot Cowork's sandbox has python3 but no mkfifo.
_runlib_mkfifo() {
  mkfifo "$1" 2>/dev/null || python3 -c 'import os, sys; os.mkfifo(sys.argv[1])' "$1" 2>/dev/null
}

report_start() {
  local name="${1:-}" version clean
  [ -n "$name" ] || { echo "report_start: a name is required" >&2; exit 2; }
  shift
  local args_ok=1 a i=0
  local parse=("$@")
  RUNLIB_NAME="$name"
  while [ "$i" -lt "${#parse[@]}" ]; do
    a="${parse[$i]}"
    case "$a" in
      --expect)
        i=$((i + 1))
        RUNLIB_EXPECT="${parse[$i]:-}"
        [ -n "$RUNLIB_EXPECT" ] || args_ok=""
        ;;
      --no-install) RUNLIB_NO_INSTALL=1 ;;
      *) args_ok="" ;;
    esac
    i=$((i + 1))
  done
  [ -n "$args_ok" ] || { echo "usage: run.sh [--expect VERSION] [--no-install]" >&2; exit 2; }

  # Failures are results here, not reasons to stop.
  set +e
  RUNLIB_TMP="$(mktemp -d)"
  RUN_TMP="$RUNLIB_TMP/work"
  mkdir -p "$RUN_TMP"
  : >"$RUNLIB_TMP/results"
  : >"$RUNLIB_TMP/allow"
  : >"$RUNLIB_TMP/attempts"

  version="$(_runlib_manifest_version "$RUNLIB_DIR/manifest.txt")"
  RUNLIB_RUN_VERSION="${version:-unknown}"
  clean="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')"
  RUNLIB_REPORT_DIR="${RUNLIB_REPORT_DIR:-$HOME/pair-run-reports}"
  mkdir -p "$RUNLIB_REPORT_DIR" || exit 2
  # The name changes every run, so an attached report never becomes "name (2).txt".
  RUNLIB_REPORT="$RUNLIB_REPORT_DIR/$clean-v${version:-0}-$(date -u +%Y%m%dT%H%M%SZ).txt"

  if ! _runlib_mkfifo "$RUNLIB_TMP/fifo"; then
    echo "report_start: can't make the report's pipe. It needs mkfifo or python3" >&2
    rm -rf "$RUNLIB_TMP"
    exit 2
  fi
  exec 8>&1 9>&2
  # -i: Ctrl-C must leave tee alive to write the verdict.
  tee -i "$RUNLIB_REPORT" <"$RUNLIB_TMP/fifo" >&8 &
  RUNLIB_TEE_PID=$!
  exec >"$RUNLIB_TMP/fifo" 2>&1

  trap _runlib_on_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  echo "PAIR-RUN REPORT"
  echo "name: $name"
  echo "version: ${version:-unknown}"
  echo "started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "system: $(uname -sm)"
  echo "runlib: $RUNLIB_VERSION"
  _runlib_wait_for_sync "$@"
}

tools() {
  local t
  echo "tools:"
  for t in "$@"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      echo "  $t: not installed"
    elif [ "$t" = go ]; then
      echo "  $t: $(go version 2>&1 | head -n 1)"
    else
      echo "  $t: $("$t" --version 2>&1 | head -n 1)"
    fi
  done
}

repo_state() {
  local d
  for d in "$@"; do
    echo "repo: $d"
    if ! git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
      echo "  not a git repository"
      continue
    fi
    echo "  branch: $(git -C "$d" rev-parse --abbrev-ref HEAD 2>&1)"
    echo "  commit: $(git -C "$d" rev-parse HEAD 2>&1)"
    echo "  status:"
    git -C "$d" status --short 2>&1 | head -n 50 | sed 's/^/    /'
  done
}

step() {
  RUNLIB_STEP=$((RUNLIB_STEP + 1))
  printf '\n== STEP %s: %s ==\n' "$RUNLIB_STEP" "$*"
}

should_install() { [ -z "$RUNLIB_NO_INSTALL" ]; }

on_exit() {
  local cmd
  cmd="$(printf '%q ' "$@")"
  eval "RUNLIB_EXIT_CMD_$RUNLIB_EXIT_COUNT=\$cmd"
  RUNLIB_EXIT_COUNT=$((RUNLIB_EXIT_COUNT + 1))
}

move_aside() {
  local path="${1%/}"
  [ -e "$path" ] || [ -L "$path" ] || { echo "move_aside: no such path: $path"; return 1; }
  [ ! -e "$path.runlib-aside" ] || { echo "move_aside: already aside: $path"; return 1; }
  mv "$path" "$path.runlib-aside" || return 1
  on_exit restore_aside "$path"
  echo "moved aside: $path"
}

restore_aside() {
  local path="${1%/}"
  [ -e "$path.runlib-aside" ] || [ -L "$path.runlib-aside" ] || return 0
  if [ -e "$path" ] || [ -L "$path" ]; then
    echo "restore_aside: $path exists again, so the original stays at $path.runlib-aside"
    return 1
  fi
  mv "$path.runlib-aside" "$path" && echo "restored: $path"
}

_runlib_checkout_print() {
  local out f
  out="$RUNLIB_TMP/checkout.$$"
  {
    git -C "$1" rev-parse HEAD
    git -C "$1" status --porcelain --untracked-files=all
    git -C "$1" diff HEAD --binary
    # Status names an untracked file, but says nothing about a change inside one.
    git -C "$1" ls-files --others --exclude-standard | while IFS= read -r f; do
      [ ! -f "$1/$f" ] || printf '%s  %s\n' "$(_runlib_sha256 "$1/$f")" "$f"
    done
  } >"$out" 2>&1
  _runlib_sha256 "$out"
}

_runlib_checkout_same() {
  [ "$(_runlib_checkout_print "$1")" = "$2" ]
  result "your checkout unchanged" $?
}

_runlib_tree_unchanged() {
  local changed
  changed="$(git -C "$1" status --porcelain --untracked-files=no)"
  [ -z "$changed" ] || printf 'changed in the worktree:\n%s\n' "$changed"
  [ -z "$changed" ]
  result "tracked files unchanged in the worktree" $?
}

_runlib_worktree_remove() {
  git -C "$1" worktree remove --force "$2" && git -C "$1" worktree prune
}

# Hooks stay off because a post-checkout hook once rewrote go.mod in a worktree, which spoiled
# every result of a real run while the user's checkout looked fine.
safe_worktree() {
  local repo="${1:-}" commit="${2:-}" hooks dirty
  [ -n "$repo" ] && [ -n "$commit" ] || abort "safe_worktree needs a repository and a commit"
  git -C "$repo" rev-parse --verify -q "$commit^{commit}" >/dev/null || abort "safe_worktree: $repo has no commit $commit"
  on_exit _runlib_checkout_same "$repo" "$(_runlib_checkout_print "$repo")"
  hooks="$RUNLIB_TMP/no-hooks"
  mkdir -p "$hooks"
  RUNLIB_WORKTREES=$((${RUNLIB_WORKTREES:-0} + 1))
  WORKTREE="$RUNLIB_TMP/worktree-$RUNLIB_WORKTREES"
  git -C "$repo" -c core.hooksPath="$hooks" worktree add -q --detach "$WORKTREE" "$commit" || abort "safe_worktree: git couldn't make a worktree of $commit"
  on_exit _runlib_worktree_remove "$repo" "$WORKTREE"
  dirty="$(git -C "$WORKTREE" -c core.hooksPath="$hooks" status --porcelain --untracked-files=all)"
  [ -z "$dirty" ] || printf 'the new worktree differs:\n%s\n' "$dirty"
  [ -z "$dirty" ]
  result "worktree identical to $commit" $?
  [ -z "$dirty" ] || abort "the worktree doesn't match $commit, so nothing run in it would count"
  on_exit _runlib_tree_unchanged "$WORKTREE"
  echo "worktree: $WORKTREE, at $commit, with git hooks off"
}

# The user's checkout gets one before-and-after check per repository, however many attempts use it.
_runlib_guard_checkout() {
  case "
$RUNLIB_GUARDED
" in
    *"
$1
"*) return 0 ;;
  esac
  RUNLIB_GUARDED="$RUNLIB_GUARDED
$1"
  on_exit _runlib_checkout_same "$1" "$(_runlib_checkout_print "$1")"
}

_runlib_worktree_gone() {
  [ ! -e "$2" ] || _runlib_worktree_remove "$1" "$2"
}

# _runlib_attempt_patches <deliverable> <attempt>: the patches an attempt applies, in order: the
# deliverable's own, then the attempt's. relay apply takes the same list for the attempt that
# passed, so what lands is what a run proved.
_runlib_attempt_patches() {
  (
    cd "$1" || exit 1
    find . -type f -name '*.patch' ! -path './attempts/*' | sed 's|^\./||' | LC_ALL=C sort
    [ -z "$2" ] || [ ! -d "attempts/$2" ] || find "attempts/$2" -type f -name '*.patch' | LC_ALL=C sort
  )
}

apply_attempt_patches() {
  local p n=0
  if [ -z "$ATTEMPT" ]; then
    echo "apply_attempt_patches: only inside an attempt"
    result "apply the attempt's patches" 1
    return 1
  fi
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    git -C "$WORKTREE" apply "$RUNLIB_DIR/$p"
    result "apply $p" $?
  done <<EOF
$(_runlib_attempt_patches "$RUNLIB_DIR" "$ATTEMPT")
EOF
  [ "$n" -gt 0 ] && return 0
  echo "apply_attempt_patches: no patches in the deliverable or in attempts/$ATTEMPT"
  result "the attempt has patches" 1
}

# One way of doing it, tried where it can't touch the user's checkout or the next attempt.
attempt() {
  local name="${1:-}" repo="${2:-}" commit="${3:-}" hooks dirty n passed failed first word=FAIL tab
  tab="$(printf '\t')"
  [ -n "$name" ] && [ -n "$repo" ] && [ -n "$commit" ] && [ $# -ge 4 ] || abort "attempt needs a name, a repository, a commit and a function"
  case "$name" in
    .* | *[!A-Za-z0-9._-]*) abort "attempt: a name is letters, digits, dots, dashes and underscores, and this isn't: $name" ;;
  esac
  ! grep -q "^PASS$tab" "$RUNLIB_TMP/attempts" || abort "attempt: one has already passed, and a deliverable has one set of attempts"
  ! grep -q "^[A-Z]*$tab$name$tab" "$RUNLIB_TMP/attempts" || abort "attempt: $name was already tried"
  git -C "$repo" rev-parse --verify -q "$commit^{commit}" >/dev/null || abort "attempt: $repo has no commit $commit"
  shift 3
  RUNLIB_ATTEMPTS=$((RUNLIB_ATTEMPTS + 1))
  n=$RUNLIB_ATTEMPTS
  printf '\n== ATTEMPT %s: %s ==\n' "$n" "$name"
  _runlib_guard_checkout "$repo"
  hooks="$RUNLIB_TMP/no-hooks"
  mkdir -p "$hooks"
  RUNLIB_WORKTREES=$((${RUNLIB_WORKTREES:-0} + 1))
  WORKTREE="$RUNLIB_TMP/worktree-$RUNLIB_WORKTREES"
  ATTEMPT="$name"
  ATTEMPT_DIR="$RUNLIB_DIR/attempts/$name"
  RUNLIB_RESULTS="$RUNLIB_TMP/attempt-$n.results"
  : >"$RUNLIB_RESULTS"
  if ! git -C "$repo" -c core.hooksPath="$hooks" worktree add -q --detach "$WORKTREE" "$commit"; then
    result "a worktree of $commit" 1
  else
    on_exit _runlib_worktree_gone "$repo" "$WORKTREE"
    dirty="$(git -C "$WORKTREE" -c core.hooksPath="$hooks" status --porcelain --untracked-files=all)"
    if [ -n "$dirty" ]; then
      printf 'the new worktree differs:\n%s\n' "$dirty"
      result "worktree identical to $commit" 1
    else
      echo "worktree: $WORKTREE, at $commit, with git hooks off"
      # A subshell, so an abort or an exit in the attempt ends the attempt and not the run.
      ("$@")
    fi
    _runlib_worktree_gone "$repo" "$WORKTREE"
  fi
  passed="$(grep -c '^PASS ' "$RUNLIB_RESULTS")"
  failed="$(grep -c '^FAIL ' "$RUNLIB_RESULTS")"
  first="$(sed -n 's/^FAIL //p' "$RUNLIB_RESULTS" | head -n 1)"
  RUNLIB_RESULTS=""
  WORKTREE=""
  ATTEMPT=""
  # shellcheck disable=SC2034
  ATTEMPT_DIR=""
  if [ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]; then
    word=PASS
  elif [ "$((passed + failed))" -eq 0 ]; then
    first="it ran no checks"
  fi
  printf '%s\t%s\t%s\n' "$word" "$name" "$first" >>"$RUNLIB_TMP/attempts"
  if [ "$word" = PASS ]; then
    echo "ATTEMPT $name: PASS, $passed checks passed"
    return 0
  fi
  echo "ATTEMPT $name: FAIL, $passed passed, $failed failed, first failure: $first"
  return 1
}

snapshot_tree() {
  local dir="${1:-}" out="${2:-}" g n
  [ -d "$dir" ] || { echo "snapshot_tree: no folder: $dir"; return 1; }
  [ -n "$out" ] || { echo "snapshot_tree: no output file named"; return 1; }
  shift 2
  local prune=(-name .git)
  for g in "$@"; do prune+=(-o -path "./$g"); done
  (cd "$dir" && find . \( "${prune[@]}" \) -prune -o \( -type f -o -type l \) -print) |
    sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r g; do
      if [ -L "$dir/$g" ]; then
        printf '%s  %s\n' "$(readlink "$dir/$g" >"$RUNLIB_TMP/link"; _runlib_sha256 "$RUNLIB_TMP/link")" "$g"
      else
        printf '%s  %s\n' "$(_runlib_sha256 "$dir/$g")" "$g"
      fi
    done >"$out"
  n="$(wc -l <"$out" | tr -d ' ')"
  # Two empty trees would compare as identical and pass for the wrong reason.
  if [ "$n" -eq 0 ]; then
    echo "snapshot_tree: nothing to snapshot in $dir"
    return 1
  fi
  echo "snapshot: $dir, $n files"
}

allow_diff() {
  printf '%s\t%s\n' "${1:-}" "${2:-no reason given}" >>"$RUNLIB_TMP/allow"
}

_runlib_snapshot_of() {
  if [ -d "$1" ]; then
    snapshot_tree "$1" "$2"
  elif [ -s "$1" ]; then
    cp "$1" "$2"
  else
    echo "compare_trees: no folder or snapshot: $1"
    return 1
  fi
}

compare_trees() {
  local left="${1:-}" right="${2:-}" l="$RUNLIB_TMP/left.$$" r="$RUNLIB_TMP/right.$$" kind path reason shown=0 bad=0 allowed=0
  _runlib_snapshot_of "$left" "$l" || { : >"$RUNLIB_TMP/allow"; return 1; }
  _runlib_snapshot_of "$right" "$r" || { : >"$RUNLIB_TMP/allow"; return 1; }
  awk '
    NR == FNR { seen[substr($0, 67)] = substr($0, 1, 64); next }
    {
      p = substr($0, 67)
      if (!(p in seen)) print "only-in-right\t" p
      else { if (seen[p] != substr($0, 1, 64)) print "changed\t" p; delete seen[p] }
    }
    END { for (p in seen) print "only-in-left\t" p }
  ' "$l" "$r" | LC_ALL=C sort -t "$(printf '\t')" -k2 >"$RUNLIB_TMP/differences"
  while IFS="$(printf '\t')" read -r kind path; do
    reason="$(awk -F '\t' -v p="$path" '$1 == p { print $2; exit }' "$RUNLIB_TMP/allow")"
    if [ -n "$reason" ]; then
      allowed=$((allowed + 1))
      echo "ALLOWED $kind $path: $reason"
      continue
    fi
    bad=$((bad + 1))
    echo "DIFF $kind $path"
    if [ "$kind" = changed ] && [ -d "$left" ] && [ -d "$right" ] && [ "$shown" -lt 5 ]; then
      shown=$((shown + 1))
      diff -u "$left/$path" "$right/$path" 2>&1 | head -n 40 | sed 's/^/    /'
    fi
  done <"$RUNLIB_TMP/differences"
  # An allowance covers one comparison, so it can't hide a difference in a later one.
  : >"$RUNLIB_TMP/allow"
  if [ "$bad" -gt 0 ]; then
    echo "compare: $bad unexplained difference(s), $allowed allowed"
    return 1
  fi
  echo "compare: $(wc -l <"$r" | tr -d ' ') files on the right, 0 unexplained differences, $allowed allowed"
}

result() {
  local name="${1:-unnamed}" rc="${2:-1}" word=FAIL
  [ "$rc" = 0 ] && word=PASS
  printf 'RESULT %s: %s\n' "$name" "$word"
  # In a file, so a result recorded in a subshell or a pipeline still counts.
  printf '%s %s\n' "$word" "$name" >>"${RUNLIB_RESULTS:-$RUNLIB_TMP/results}"
}

check() {
  local name="$1"
  shift
  "$@"
  result "$name" $?
}

# A plain non-zero exit isn't enough: a negative test once passed because the command
# failed for an unrelated reason.
expect_fail_with() {
  local name="$1" pattern="$2" out rc
  shift 2
  out="$("$@" 2>&1)"
  rc=$?
  printf '%s\n' "$out" | tail -n 40 | sed 's/^/    /'
  if [ "$rc" -eq 0 ]; then
    echo "expected a failure, but it exited 0"
    result "$name" 1
  elif printf '%s\n' "$out" | grep -F -q -- "$pattern"; then
    result "$name" 0
  else
    echo "it failed (exit $rc), but for the wrong reason: no \"$pattern\" in the output"
    result "$name" 1
  fi
}

abort() {
  echo "ABORT: $*"
  result "abort: $*" 1
  exit 1
}

report_end() {
  RUNLIB_ENDED=1
  exit 0
}

_runlib_on_exit() {
  local rc=$? i cmd passed failed first word=FAIL upper code=1 won="" a_word a_name a_first
  trap - EXIT INT TERM
  i=$RUNLIB_EXIT_COUNT
  while [ "$i" -gt 0 ]; do
    i=$((i - 1))
    eval "cmd=\$RUNLIB_EXIT_CMD_$i"
    if ! eval "$cmd"; then
      result "cleanup: $cmd" 1
    fi
  done
  RUNLIB_RESULTS=""
  # A set of attempts counts once: one of them passed, or none did.
  if [ -s "$RUNLIB_TMP/attempts" ]; then
    won="$(awk -F '\t' '$1 == "PASS" { print $2; exit }' "$RUNLIB_TMP/attempts")"
    if [ -n "$won" ]; then
      printf 'PASS an attempt passed: %s\n' "$won" >>"$RUNLIB_TMP/results"
    else
      printf 'FAIL no attempt passed\n' >>"$RUNLIB_TMP/results"
    fi
  fi
  passed="$(grep -c '^PASS ' "$RUNLIB_TMP/results")"
  failed="$(grep -c '^FAIL ' "$RUNLIB_TMP/results")"
  first="$(sed -n 's/^FAIL //p' "$RUNLIB_TMP/results" | head -n 1)"
  printf '\n== SUMMARY ==\n'
  # Here too, so the end of a report is enough on its own.
  echo "version: $RUNLIB_RUN_VERSION"
  if [ -s "$RUNLIB_TMP/attempts" ]; then
    echo "attempts: $(wc -l <"$RUNLIB_TMP/attempts" | tr -d ' ') tried"
    while IFS="$(printf '\t')" read -r a_word a_name a_first; do
      if [ "$a_word" = PASS ]; then
        echo "  $a_name: PASS"
      else
        echo "  $a_name: FAIL, first failure: $a_first"
      fi
    done <"$RUNLIB_TMP/attempts"
    # relay apply reads this line to know which attempt's patches were proven.
    [ -z "$won" ] || echo "attempt passed: $won"
  fi
  if [ -s "$RUNLIB_TMP/attempts" ]; then
    echo "checks: $passed passed, $failed failed, not counting the checks inside attempts"
  else
    echo "checks: $passed passed, $failed failed"
  fi
  [ -z "$first" ] || echo "first failure: $first"
  if [ -z "$RUNLIB_ENDED" ]; then
    echo "ended early, exit code $rc, before report_end"
  elif [ "$((passed + failed))" -eq 0 ]; then
    echo "no checks ran, so nothing was proved"
  elif [ "$failed" -eq 0 ]; then
    word=PASS
    code=0
  fi
  echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  upper="$(printf '%s' "$RUNLIB_NAME" | tr '[:lower:]' '[:upper:]')"
  echo "$upper RUN: $word"
  _runlib_close_report
  rm -rf "$RUNLIB_TMP"
  echo "Report: $RUNLIB_REPORT"
  exit "$code"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    manifest)
      shift
      runlib_manifest "$@"
      exit $?
      ;;
    *)
      echo "usage: bash runlib.sh manifest DIR [VERSION]. To use it in a run.sh, source it." >&2
      exit 2
      ;;
  esac
fi
