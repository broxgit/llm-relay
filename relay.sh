#!/usr/bin/env bash
# relay: the Mac's side of the remote pair-run loop with Microsoft Copilot Cowork.
#
#   relay setup   Put the remote-pair-run skill in OneDrive, and record where things are.
#   relay run     Wait for a deliverable, copy it out of OneDrive, and run the copy on a keypress.
#   relay scan    Put a repository in OneDrive for Cowork to read, in place of an attached scan.
#   relay mr      Put a merge request and what it takes to review it in OneDrive.
#   relay review  Save the review Cowork wrote where you keep your reviews.
#   relay apply   Leave a proven patch in your working tree, uncommitted.
#   relay skills  Say where Cowork's copies of your own skills stand.
#   relay field-test  Have Cowork guide you through a test, and write a report on it.
#
# Works with the bash that ships on macOS (3.2) and on Linux.
# shellcheck disable=SC2034  # RUNLIB_DIR and RUNLIB_EXPECT are read by runlib.sh.
set -u
# Feed a loop with a heredoc holding $(...), not process substitution, which can interrupt a
# blocked printf on bash 3.2. Empty output gives one blank line, so a loop needs its own guard.

# Follow symlinks, such as ~/.local/bin/relay, to the real script: the skill sits beside it.
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
REPO="$(cd "$(dirname "$src")" && pwd)"
SKILL_DIR="$REPO/cowork/remote-pair-run"
RUNLIB="$SKILL_DIR/runlib.sh"
# The skills that are the relay's own. relay setup copies them to Cowork as they are.
OWN_SKILLS="remote-pair-run relay-field-test"
# shellcheck source=/dev/null
. "$RUNLIB"

die() { echo "error: $*" >&2; exit 1; }

# The release this is. docs/releasing.md says how to make the next one.
RELAY_VERSION="0.2.2"

COWORK=""
WAIT="${RELAY_WAIT:-600}"
POLL="${RELAY_POLL:-5}"
READ_LIMIT="${RELAY_READ_LIMIT:-120}"
CHECK_LIMIT="${RELAY_CHECK_LIMIT:-600}"
REPORTS="${RUNLIB_REPORT_DIR:-$HOME/pair-run-reports}"
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/llm-relay/settings"
# Where the settings lived when the relay was part of llm-wiki. Read, never written.
OLD_SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/llm-wiki/relay"
WORK=""
RUN_STARTED=""
KEY=""

# Whether there's someone to ask. Standard input has to be a terminal, so an agent's shell is
# refused even when it inherits one, and /dev/tty has to open, because the answers are read from
# it. No variable or flag changes this. Worked out once, here: later, standard input can be a
# loop's heredoc.
AT_TERMINAL=no
if [ -t 0 ] && (exec 3<>/dev/tty) 2>/dev/null; then AT_TERMINAL=yes; fi

cleanup() {
  [ -z "$WORK" ] || rm -rf "$WORK"
  [ -z "$RUN_STARTED" ] || echo "Relay run ended at $(now)."
}

# setting <key> <default>: a line of the settings file `relay setup` writes, or of the old one
# for a key the new file doesn't have yet.
setting() {
  local v
  v="$(sed -n "s/^$1=//p" "$SETTINGS" 2>/dev/null | tail -n 1)"
  [ -n "$v" ] || v="$(sed -n "s/^$1=//p" "$OLD_SETTINGS" 2>/dev/null | tail -n 1)"
  printf '%s' "${v:-$2}"
}
REVIEWS_DIR="$(setting reviews "$HOME/mr-reviews")"
CLONES_DIRS="$(setting clones "$HOME/dev")"
# The user's own skills that Cowork gets a copy of, by name, and where they live.
SKILLS="$(setting skills "")"
SKILLS_FROM="$(setting skills_from "$HOME/.claude/skills")"
SKILLS_DIR=""
SKILLS_CHECKED=""
SKILL_TMP=""
SKILL_STATE=""
SKILL_SHA=""
OWN_SKILL_STATE=""
COPY_STATE=""
# The version of the note the relay puts on a copied skill. A new number makes every copy again.
SKILL_TEMPLATE=1
SKILL_START='<!-- relay:start -->'
SKILL_END='<!-- relay:end -->'
# Tools a skill written for Claude may name, and Cowork's sandbox doesn't have.
COWORK_LACKS="glab gh curl wget ssh scp docker kubectl jira acli aws mongosh psql"

usage() {
  cat <<EOF
Usage: relay setup [--dir ONEDRIVE_FOLDER] [--reviews FOLDER] [--clones FOLDERS] [--skills NAMES]
       relay [--dir ONEDRIVE_FOLDER] skills
       relay [--dir ONEDRIVE_FOLDER] field-test [--clean]
       relay completion zsh|bash
       relay --version
       relay [--dir ONEDRIVE_FOLDER] run [TASK-FOLDER/DELIVERABLE] [--expect VERSION] [--no-install]
       relay [--dir ONEDRIVE_FOLDER] scan [REPOSITORY] [--branch NAME] [--no-wiki]
       relay [--dir ONEDRIVE_FOLDER] mr URL... [--also PATH[@BRANCH]]... [--repo PATH] [--go-prefix PREFIX]... [--checks | --no-checks] [--no-wiki]
       relay [--dir ONEDRIVE_FOLDER] review TASK-FOLDER/DELIVERABLE [--expect VERSION]
       relay [--dir ONEDRIVE_FOLDER] apply TASK-FOLDER/DELIVERABLE --repo PATH [--expect VERSION]

  setup  Copies the remote-pair-run skill to Documents/Cowork/skills in your work OneDrive.
         Run it again to update the skill. --skills copies your own Claude skills there too,
         each with a note on what to do differently in Cowork. setup --help has more.
  skills Says where Cowork's copy of each of your skills stands, and changes nothing.
  field-test
         Starts a guided test. It makes a small repository at ~/relay-field-test for the
         test to change, puts a note about this Mac's setup in OneDrive, with no paths or
         names of yours in it, and a prompt for Cowork on the clipboard. Cowork then walks
         you through each step and writes a report, which relay review saves.
         --clean removes that repository and what the test left in OneDrive.
  run    Waits until a deliverable from Copilot Cowork matches its manifest, copies it to a
         local folder, shows you what's there, and runs the copy when you press y. If it gives up, it says what this Mac sees. The report
         goes to Documents/Cowork/relay/<task-folder>/reports in OneDrive, only if a run
         happened. Then tell Cowork "done". With no deliverable named, it uses the newest.
  scan   Puts the repository's current branch and uncommitted changes in OneDrive, at
         Documents/Cowork/relay/scans, with a note of the commit and tool versions. Untracked
         files stay out. Defaults to the repository you're in. If you use llm-wiki, the compiled
         pages of the wiki that covers it go too, unless you add --no-wiki. Its raw notes and
         other wikis stay out.
         --branch NAME scans that branch instead, as origin has it after a fetch, or your
         local copy if origin doesn't have it. Your checkout isn't touched, and uncommitted
         changes stay out.
  mr     Fetches a GitLab merge request with glab, and puts it in OneDrive for Cowork to review:
         its discussions and diff, its source and target branches, the libraries its go.mod
         pins, your earlier review if there is one, and its wiki. It only fetches in your
         clone, finds the clone under $CLONES_DIRS, and puts a prompt for Cowork on the clipboard.
         --also sends another repository, or just one folder of it, at origin's default
         branch or the one you name. Use it as many times as you like. --go-prefix says which
         modules count as yours, if it's not the ones that share your module's host.
         If it's Go, it asks whether to run go build, vet, test and mod tidy on a temporary
         copy of the branch first, and sends the results. --checks and --no-checks answer for you.
  review Waits for the review Cowork published, shows it and what it says it covered, and when
         you press y saves it under $REVIEWS_DIR. A copy you already have is kept as
         <name>.previous.
  apply  Waits for a deliverable, and when you press y applies its patches to the repository's
         working tree. It never commits. Use it once a run has passed.
EOF
}

# ---- run ---------------------------------------------------------------------

# deliverable_path <TASK-FOLDER/DELIVERABLE>: where it is in OneDrive.
deliverable_path() {
  case "$1" in
    */*/* | /* | */ | ..* | */..) die "name a deliverable as TASK-FOLDER/DELIVERABLE: $1" ;;
    */*) printf '%s' "$COWORK/Tasks/${1%%/*}/output/${1#*/}" ;;
    *) die "name a deliverable as TASK-FOLDER/DELIVERABLE: $1" ;;
  esac
}

needs_terminal() {
  [ "$AT_TERMINAL" = yes ] || die "relay $1 asks before it does anything, so it needs a terminal. Agents: tell the user to run it."
}

# ask_key <prompt>: one keypress, in KEY. Asked and answered at the terminal itself, so nothing
# piped in can answer and the question shows even when the output goes elsewhere.
ask_key() {
  printf '%s' "$1" >/dev/tty
  IFS= read -r -n 1 KEY </dev/tty || { echo >/dev/tty; return 1; }
  # Enter has already moved to a new line.
  [ -z "$KEY" ] || echo >/dev/tty
}

newest_deliverable() {
  local m best=""
  for m in "$COWORK"/Tasks/*/output/*/manifest.txt; do
    [ -f "$m" ] || continue
    if [ -z "$best" ] || [ "$m" -nt "$best" ]; then best="$m"; fi
  done
  printf '%s' "${best%/manifest.txt}"
}

manifest_paths() {
  sed -n 's/^sha256 [0-9a-f]*  \(.*\)$/\1/p' "$1/manifest.txt" 2>/dev/null
}

# The manifest comes from the cloud, so it can't name a file outside the folder.
check_manifest_paths() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "/$p/" in
      */../* | //*) die "the manifest names a path outside its folder: $p" ;;
    esac
  done <<EOF
$(manifest_paths "$1")
EOF
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# macOS marks files with attributes such as com.apple.provenance, and Linux tar warns about each one.
make_archive() {
  local out="$1"
  shift
  COPYFILE_DISABLE=1 tar --no-xattrs -czf "$out" "$@" 2>/dev/null || COPYFILE_DISABLE=1 tar -czf "$out" "$@"
}

# What this Mac says about a file, without reading it. A refusal shows up here too.
describe_file() {
  local out
  out="$(stat -c 'size %s, %b blocks' "$1" 2>/dev/null)" || out="$(stat -f 'size %z, %b blocks, flags %Sf' "$1" 2>&1)"
  printf '%s' "${out##*: }"
}

# Runs a command for at most $1 seconds, so a download that never finishes can't outlast the wait.
limited() {
  local secs="$1" pid i=0
  shift
  "$@" </dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge $((secs * 10)) ]; then
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 0.1
    i=$((i + 1))
  done
  wait "$pid" 2>/dev/null
}

# Reads a file out of OneDrive. A read is what makes OneDrive download a file that's only in
# the cloud. This is the only way anything here reads the synced folder, and it always says
# why it couldn't.
read_file() {
  local src="$1" dst="$2" name="$3" rc why
  limited "$READ_LIMIT" cat "$src" >"$dst" 2>"$WORK/read.err"
  rc=$?
  [ "$rc" -eq 0 ] && return 0
  why="$(head -n 1 "$WORK/read.err")"
  case "$rc:$why" in
    124:*) why="still reading after ${READ_LIMIT}s" ;;
    137:*) why="the read was killed" ;;
    *"No such file"*) echo "$name is missing"; return 1 ;;
    *) why="${why##*: }" ;;
  esac
  echo "$name can't be read: ${why:-exit $rc} ($(describe_file "$src"))"
  return 1
}

# One try at copying a deliverable. Copies only what the manifest lists, because Cowork can't
# delete old files from OneDrive, and checks the copy, so nothing can be half-delivered. Prints
# each problem, and prints nothing when the copy is good.
try_copy() {
  local src="$1" dst="$2" p version bad=""
  rm -rf "$dst"
  mkdir -p "$dst" || { echo "can't write to $dst"; return 1; }
  read_file "$src/manifest.txt" "$dst/manifest.txt" manifest.txt || return 1
  version="$(_runlib_manifest_version "$dst/manifest.txt")"
  if [ -z "$version" ]; then
    echo "manifest.txt has no version line: read $(wc -c <"$dst/manifest.txt" | tr -d ' ') bytes, starting $(head -c 12 "$dst/manifest.txt" | od -An -tx1 | tr -s ' ' | sed 's/^ //; s/ $//') ($(describe_file "$src/manifest.txt"))"
    return 1
  fi
  if [ -n "$RUNLIB_EXPECT" ] && [ "$version" != "$RUNLIB_EXPECT" ]; then
    echo "manifest.txt is version $version, expected $RUNLIB_EXPECT"
    return 1
  fi
  check_manifest_paths "$dst"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    mkdir -p "$dst/$(dirname "$p")" || { echo "can't write to $dst"; return 1; }
    read_file "$src/$p" "$dst/$p" "$p" || bad=1
  done <<EOF
$(manifest_paths "$dst")
EOF
  [ -z "$bad" ] || return 1
  RUNLIB_DIR="$dst"
  _runlib_sync_problems
}

# iTerm was refused for over an hour while Apple's Terminal read the same files at once,
# though not every time. So say it the moment it shows, not after the wait.
refusal_advice() {
  if [ "${TERM_PROGRAM:-}" = Apple_Terminal ]; then
    echo "macOS is refusing to let Apple's Terminal read OneDrive files that aren't on this Mac yet. More waiting rarely helps."
    echo "If your OneDrive allows it, in Finder, right-click the task's output folder and choose Always Keep on This Device."
  else
    echo "macOS is refusing to let ${TERM_PROGRAM:-this terminal app} read OneDrive files that aren't on this Mac yet. More waiting rarely helps."
    echo "Press Ctrl-C, and run the same command in Apple's Terminal, which could read them in one test."
  fi
}

# Keeps trying through every way OneDrive has shown a file isn't ready: missing, out of date,
# unreadable, or refused with "Operation not permitted".
wait_for_deliverable() {
  local named="$1" dst="$2" start="$SECONDS" waited=0 said=0 advised="" problems last=""
  while :; do
    SRC="$named"
    [ -n "$SRC" ] || SRC="$(newest_deliverable)"
    if [ -z "$SRC" ]; then
      problems="no deliverable in $COWORK/Tasks yet"
      # A refused folder looks empty to a glob.
      if ! ls "$COWORK/Tasks" >/dev/null 2>"$WORK/read.err"; then
        grep -q "No such file" "$WORK/read.err" || problems="can't list $COWORK/Tasks: $(sed 's/^.*: //' "$WORK/read.err" | head -n 1)"
      fi
    else
      try_copy "$SRC" "$dst" >"$WORK/problems"
      problems="$(cat "$WORK/problems")"
      if [ -z "$problems" ]; then
        [ -z "$last" ] || echo "Ready after $((SECONDS - start))s."
        return 0
      fi
    fi
    waited=$((SECONDS - start))
    if [ "$problems" != "$last" ]; then
      echo "Waiting for OneDrive (${waited}s of ${WAIT}s):"
      printf '%s\n' "$problems" | head -n 8 | sed 's/^/  /'
      last="$problems"
      said="$waited"
      case "$problems" in
        *"Operation not permitted"*)
          if [ -z "$advised" ]; then
            refusal_advice
            advised=1
          fi
          ;;
      esac
    elif [ $((waited - said)) -ge 60 ]; then
      echo "Still waiting (${waited}s of ${WAIT}s)."
      said="$waited"
    fi
    if [ "$waited" -ge "$WAIT" ]; then
      {
        echo "Still not ready after ${waited}s, at $(now), so nothing ran and no report was sent."
        echo "Paste this output to Cowork. If your OneDrive allows it, in Finder, right-click the task's output folder, choose Always Keep on This Device, and run the same command again."
      } >&2
      return 1
    fi
    sleep "$POLL"
  done
}

show_deliverable() {
  local copy="$1" where="$2" version="$3" p size same="differs from this machine's copy"
  cmp -s "$copy/runlib.sh" "$RUNLIB" && same="same as this machine's copy"
  echo
  echo "Deliverable: $where"
  echo "Version:     $version"
  echo "Files:"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    size="$(wc -c <"$copy/$p" | tr -d ' ')"
    case "$p" in
      runlib.sh) echo "  $p ($size bytes, $same)" ;;
      *) echo "  $p ($size bytes)" ;;
    esac
  done <<EOF
$(manifest_paths "$copy")
EOF
  echo
}

view_deliverable() {
  local copy="$1" p
  {
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # A runlib.sh that differs from this machine's is the one to read, so only a match is skipped.
      if [ "$p" = runlib.sh ] && cmp -s "$copy/$p" "$RUNLIB"; then
        printf "\n===== %s: same as this machine's copy, not shown =====\n" "$p"
        continue
      fi
      printf '\n===== %s =====\n' "$p"
      cat "$copy/$p"
    done <<EOF
$(manifest_paths "$copy")
EOF
  } | ${PAGER:-less} >/dev/tty
}

# Nothing from the cloud runs until someone says so here.
ask_to_run() {
  local copy="$1" question="${2:-Run it?}"
  while :; do
    ask_key "$question [y]es, [v]iew the files, [n]o: " || return 1
    case "$KEY" in
      y | Y) return 0 ;;
      n | N) return 1 ;;
      v | V) view_deliverable "$copy" ;;
    esac
  done
}

send_report() {
  local report="$1" task="$2" dir i=0
  dir="$COWORK/relay/$task/reports"
  while [ "$i" -lt 3 ]; do
    if mkdir -p "$dir" 2>/dev/null && cp "$report" "$dir/" 2>/dev/null && cmp -s "$report" "$dir/$(basename "$report")"; then
      echo
      echo "Sent to OneDrive: Documents/Cowork/relay/$task/reports/$(basename "$report")"
      echo 'Now tell Cowork: done'
      return 0
    fi
    i=$((i + 1))
    [ "$i" -lt 3 ] && sleep "$POLL"
  done
  echo
  echo "Couldn't put the report in OneDrive. Attach it in Cowork instead: $report" >&2
  return 1
}

# A task's deliverables share one reports folder, and a report is named by its run.sh, not by
# its deliverable. So relay run keeps its own record of which report came from which files, on
# this Mac, where nothing in the cloud can change it. A line is the manifest's hash, the
# deliverable, its version and the report's name, with tabs between.
record_run() {
  printf '%s\t%s\t%s\t%s\n' "$(sha256_of "$1")" "$2" "$3" "$4" >>"$REPORTS/.relay-runs" 2>/dev/null || true
}

# last_run_report <manifest>: the report this Mac kept from its last run of exactly these files.
last_run_report() {
  local name
  [ -f "$REPORTS/.relay-runs" ] || return 0
  name="$(awk -F '\t' -v h="$(sha256_of "$1")" '$1 == h { r = $4 } END { if (r != "") print r }' "$REPORTS/.relay-runs")"
  case "$name" in '' | */*) return 0 ;; esac
  [ ! -f "$REPORTS/$name" ] || echo "$REPORTS/$name"
}

cmd_run() {
  local named="" where="" expect="" no_install="" a rc copy version task new
  while [ $# -gt 0 ]; do
    case "$1" in
      --expect)
        [ -n "${2:-}" ] || die "--expect needs a version"
        expect="$2"
        shift 2
        ;;
      --no-install) no_install=1; shift ;;
      -h | --help) usage; return 0 ;;
      -*) die "relay run: unknown option $1. Try relay --help" ;;
      *)
        [ -z "$where" ] || die "relay run takes one deliverable"
        where="$1"
        shift
        ;;
    esac
  done
  if [ -n "$where" ]; then
    named="$(deliverable_path "$where")" || exit 1
  fi
  needs_terminal run

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  trap cleanup EXIT
  copy="$WORK/deliverable"
  RUNLIB_EXPECT="$expect"
  echo "Relay run started at $(now)."
  RUN_STARTED=1
  wait_for_deliverable "$named" "$copy" || return 1

  version="$(_runlib_manifest_version "$copy/manifest.txt")"
  a="${SRC%/*}"
  task="$(basename "${a%/*}")"
  show_deliverable "$copy" "$task/$(basename "$SRC")" "$version"
  if ! ask_to_run "$copy"; then
    echo "Nothing ran, and no report was sent."
    return 1
  fi

  mkdir -p "$REPORTS" || die "can't create $REPORTS"
  ls "$REPORTS" | LC_ALL=C sort >"$WORK/before"
  echo
  # The copy already matches its manifest, so runlib has nothing to wait for.
  if [ -n "$no_install" ]; then
    RUNLIB_REPORT_DIR="$REPORTS" RUNLIB_SYNC_WAIT=0 bash "$copy/run.sh" --expect "$version" --no-install
  else
    RUNLIB_REPORT_DIR="$REPORTS" RUNLIB_SYNC_WAIT=0 bash "$copy/run.sh" --expect "$version"
  fi
  rc=$?

  # A report from this run only: an older one in the folder must never go out in its place.
  new="$(ls "$REPORTS" | LC_ALL=C sort | LC_ALL=C comm -13 "$WORK/before" - | tail -n 1)"
  if [ -z "$new" ]; then
    echo
    echo "That run wrote no report, so nothing was sent to Cowork. Its output is above." >&2
    [ "$rc" -ne 0 ] || rc=1
    return "$rc"
  fi
  record_run "$copy/manifest.txt" "$task/$(basename "$SRC")" "$version" "$new"
  send_report "$REPORTS/$new" "$task" || { [ "$rc" -ne 0 ] || rc=1; }
  return "$rc"
}

# ---- scan --------------------------------------------------------------------

# Copies one wiki's index and compiled pages for Cowork to read, and prints how many pages.
# Markdown only, so raw notes, the log and anything else in the wiki stay on this machine.
copy_wiki() {
  local wiki="$1" dst="$2"
  mkdir -p "$dst" || return 1
  cp "$wiki/index.md" "$dst/index.md" || return 1
  if [ -d "$wiki/wiki" ]; then
    cp -R "$wiki/wiki" "$dst/wiki" || return 1
    find "$dst/wiki" ! -type f ! -type d -exec rm -f {} +
    find "$dst/wiki" -type f ! -name '*.md' -exec rm -f {} +
    find "$dst/wiki" -type f -name '.*' -exec rm -f {} +
  fi
  find "$dst" -type f -name '*.md' ! -path "$dst/index.md" | wc -l | tr -d ' '
}

# Finds a named branch, preferring origin's copy, so "master" means what everyone else sees.
# Sets SCAN_REF to the ref and SCAN_SOURCE to what to call it.
find_branch() {
  local root="$1" want="$2"
  git check-ref-format --branch "$want" >/dev/null 2>&1 || die "not a branch name: $want"
  if git -C "$root" remote get-url origin >/dev/null 2>&1; then
    if GIT_TERMINAL_PROMPT=0 git -C "$root" fetch -q origin "+refs/heads/$want:refs/remotes/origin/$want" 2>/dev/null; then
      SCAN_REF="refs/remotes/origin/$want"
      SCAN_SOURCE="origin/$want"
      return 0
    fi
    if git -C "$root" rev-parse --verify -q "refs/remotes/origin/$want" >/dev/null; then
      SCAN_REF="refs/remotes/origin/$want"
      SCAN_SOURCE="origin/$want as of your last fetch, because origin couldn't be reached"
      return 0
    fi
  fi
  git -C "$root" rev-parse --verify -q "refs/heads/$want" >/dev/null || die "no branch named $want, on origin or here"
  SCAN_REF="refs/heads/$want"
  SCAN_SOURCE="your local $want, not on origin"
}

# collect_wiki <folder> <repository name, or empty for the folder's own> <no-wiki flag>: copies the wiki that covers a repository into the
# scratch folder, and sets WIKI_LINE, WIKI_NAME, WIKI_PAGES and WIKI_PART for the caller.
# Only that wiki. The shared wiki can hold personal rules, so it stays out. The wiki command is
# llm-wiki's, and optional: with none installed, the relay works and sends no wiki.
collect_wiki() {
  local wiki=""
  WIKI_LINE="none covers this repository"
  WIKI_NAME=""
  WIKI_PAGES=0
  WIKI_PART=""
  if [ -n "$3" ]; then
    WIKI_LINE="left out with --no-wiki"
    return 0
  fi
  if ! command -v wiki >/dev/null 2>&1; then
    WIKI_LINE="left out, because this machine has no wiki command"
    echo "No wiki command here, so no wiki copy goes with this."
    return 0
  fi
  # From the repository's folder, so wiki picks the collection that holds its wiki.
  wiki="$(cd "$1" && wiki which ${2:+"$2"} 2>/dev/null)" || wiki=""
  # wiki which shortens the path to a literal ~/.
  # shellcheck disable=SC2088
  case "$wiki" in "~/"*) wiki="$HOME/${wiki#"~/"}" ;; esac
  WIKI_NAME="${wiki##*/}"
  if [ "$WIKI_NAME" = global ]; then
    wiki=""
    WIKI_LINE="left out, because the shared wiki isn't sent"
  fi
  [ -n "$wiki" ] || return 0
  WIKI_PAGES="$(copy_wiki "$wiki" "$WORK/repo-wiki")" || die "couldn't copy the $WIKI_NAME wiki"
  if [ "$WIKI_PAGES" -gt 0 ]; then
    WIKI_LINE="$WIKI_NAME, compiled pages: $WIKI_PAGES, start at repo-wiki/index.md in the archive"
    WIKI_PART="repo-wiki"
  else
    WIKI_LINE="$WIKI_NAME has no pages yet"
  fi
}

# scratch_fetch <clone> <scratch repository> <ref in the clone> <ref to make>: copies a ref into
# a scratch repository. A partial clone can't hand over files it never downloaded, so that one
# comes from origin itself.
scratch_fetch() {
  local root="$1" scratch="$2" src="$3" dst="$4" url remote
  if [ -z "$(git -C "$root" config --get remote.origin.partialclonefilter 2>/dev/null)" ]; then
    git -C "$scratch" fetch -q "$root" "+$src:$dst"
    return $?
  fi
  url="$(git -C "$root" config --get remote.origin.url)"
  case "$src" in
    refs/remotes/origin/merge-requests/*) remote="refs/merge-requests/${src##*/}/head" ;;
    refs/remotes/origin/*) remote="refs/heads/${src#refs/remotes/origin/}" ;;
    *) echo "$root is a partial clone, so it can't send the local branch $src." >&2; return 1 ;;
  esac
  GIT_TERMINAL_PROMPT=0 git -C "$scratch" fetch -q "$url" "+$remote:$dst"
}

# Scans have reached Cowork at up to 50 MB. Past that, nobody knows, so say so.
size_warning() {
  [ "$1" -le 52428800 ] || echo "That's over 50 MB, the largest size tried with Cowork. If it can't read it, try without the wiki or with fewer repositories."
}

list_tools() {
  local t
  for t in go git buf protoc python3 node glab; do
    command -v "$t" >/dev/null 2>&1 || continue
    if [ "$t" = go ]; then
      echo "  go: $(go version 2>&1 | head -n 1)"
    else
      echo "  $t: $("$t" --version 2>&1 | head -n 1)"
    fi
  done
}

cmd_scan() {
  local dir="." root name branch commit size hash dest dirty=no no_wiki="" want=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help) usage; return 0 ;;
      --no-wiki) no_wiki=1; shift ;;
      --branch)
        [ -n "${2:-}" ] || die "--branch needs a branch name"
        want="$2"
        shift 2
        ;;
      -*) die "relay scan: unknown option $1. Try relay --help" ;;
      *) dir="$1"; shift ;;
    esac
  done
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || die "not a git repository: $dir"
  name="$(basename "$root" | tr -c 'A-Za-z0-9._\n-' '-')"
  # Cowork is about to be asked for something, so its copies of the user's skills should be current.
  if [ -z "$SKILLS_CHECKED" ]; then
    SKILLS_CHECKED=1
    check_own_skill
    sync_skills quiet
  fi
  [ -n "$name" ] || die "can't name a scan after $root"
  if [ -n "$want" ]; then
    find_branch "$root" "$want"
    commit="$(git -C "$root" rev-parse --verify -q "$SCAN_REF")" || die "can't read $want"
    branch="$want"
  else
    commit="$(git -C "$root" rev-parse --verify -q HEAD)" || die "$root has no commits yet"
    branch="$(git -C "$root" symbolic-ref -q --short HEAD)" || branch=""
  fi

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  trap cleanup EXIT
  if [ -n "$want" ]; then
    # A scratch repository, so the clone gets the branch under its own name, without moving
    # any branch in the real one.
    git init -q --bare "$WORK/branch.git" || die "git couldn't make a scratch repository"
    scratch_fetch "$root" "$WORK/branch.git" "$SCAN_REF" "refs/heads/$want" || die "git couldn't read $want from $root"
    git -C "$WORK/branch.git" symbolic-ref HEAD "refs/heads/$want"
    git -C "$WORK/branch.git" bundle create -q "$WORK/repo.bundle" HEAD "refs/heads/$want" || die "git couldn't bundle $want"
    : >"$WORK/uncommitted.patch"
  elif [ -n "$branch" ]; then
    git -C "$root" bundle create -q "$WORK/repo.bundle" HEAD "refs/heads/$branch" || die "git couldn't bundle $root"
  else
    git -C "$root" bundle create -q "$WORK/repo.bundle" HEAD || die "git couldn't bundle $root"
  fi
  if [ -z "$want" ]; then
    git -C "$root" diff HEAD --binary >"$WORK/uncommitted.patch" || die "git couldn't read the uncommitted changes"
    [ -s "$WORK/uncommitted.patch" ] && dirty=yes
  fi

  collect_wiki "$root" "" "$no_wiki"
  {
    echo "LLM-RELAY SCAN"
    echo "repository: $name"
    echo "path: $root"
    echo "branch: ${branch:-detached}"
    [ -z "$want" ] || echo "source: $SCAN_SOURCE"
    echo "commit: $commit"
    echo "taken: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "wiki: $WIKI_LINE"
    if [ "$dirty" = yes ]; then
      echo "uncommitted changes: yes, in uncommitted.patch"
    elif [ -n "$want" ]; then
      echo "uncommitted changes: left out, because this is a scan of another branch. uncommitted.patch is empty"
    else
      echo "uncommitted changes: no, uncommitted.patch is empty"
    fi
    if [ -z "$want" ]; then
      echo "status (untracked files, marked ??, are not in the archive):"
      git -C "$root" status --short | head -n 200 | sed 's/^/  /'
    fi
    echo "tools:"
    list_tools
  } >"$WORK/scan.txt"
  # COPYFILE_DISABLE keeps macOS's tar from adding ._ files.
  make_archive "$WORK/$name.tar.gz" -C "$WORK" repo.bundle uncommitted.patch scan.txt ${WIKI_PART:+"$WIKI_PART"} || die "tar couldn't make the archive"
  hash="$(sha256_of "$WORK/$name.tar.gz")"
  size="$(wc -c <"$WORK/$name.tar.gz" | tr -d ' ')"
  {
    cat "$WORK/scan.txt"
    echo "archive: $name.tar.gz"
    echo "archive sha256: $hash"
    echo "archive bytes: $size"
  } >"$WORK/$name.txt"

  dest="$COWORK/relay/scans"
  mkdir -p "$dest" || die "can't create $dest"
  # The note goes last, so its hash never describes an archive that isn't there yet.
  cp "$WORK/$name.tar.gz" "$dest/" || die "couldn't copy the archive to $dest"
  cp "$WORK/$name.txt" "$dest/" || die "couldn't copy the note to $dest"
  if [ -n "$want" ]; then
    echo "Scanned $name: $want at $commit, from $SCAN_SOURCE, $size bytes, uncommitted changes left out"
  else
    echo "Scanned $name: ${branch:-detached HEAD} at $commit, $size bytes, uncommitted changes: $dirty"
  fi
  [ -z "$WIKI_PART" ] || echo "Included the $WIKI_NAME wiki (compiled pages: $WIKI_PAGES, no raw notes). Add --no-wiki to leave it out."
  size_warning "$size"
  echo "Sent to OneDrive: Documents/Cowork/relay/scans/$name.txt and $name.tar.gz"
  echo "Now tell Cowork: read Documents/Cowork/relay/scans/$name.txt"
}

# ---- also --------------------------------------------------------------------

default_branch() {
  local d
  d="$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  if [ -n "$d" ]; then
    printf '%s' "${d#origin/}"
  elif git -C "$1" rev-parse --verify -q refs/remotes/origin/master >/dev/null || git -C "$1" rev-parse --verify -q refs/heads/master >/dev/null; then
    printf master
  else
    printf main
  fi
}

# send_also <PATH[@BRANCH]>: another repository for Cowork, or one folder of it, as a plain scan
# of its own. Prints the note's place in OneDrive on the last line.
send_also() {
  local spec="$1" path branch="" root sub name ref commit size hash dest t
  path="${spec%@*}"
  [ "$path" = "$spec" ] || branch="${spec##*@}"
  # shellcheck disable=SC2088
  case "$path" in "~/"*) path="$HOME/${path#"~/"}" ;; esac
  root="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" || die "--also: not in a git repository: $path"
  sub="$(git -C "$path" rev-parse --show-prefix)"
  [ -n "$branch" ] || branch="$(default_branch "$root")"
  if [ -z "$sub" ]; then
    (cmd_scan "$root" --branch "$branch" --no-wiki) >&2 || die "--also: couldn't scan $path"
    echo "Documents/Cowork/relay/scans/$(basename "$root" | tr -c 'A-Za-z0-9._\n-' '-').txt"
    return 0
  fi
  find_branch "$root" "$branch"
  ref="$SCAN_REF"
  commit="$(git -C "$root" rev-parse --verify -q "$ref")" || die "--also: can't read $branch"
  sub="${sub%/}"
  name="$(basename "$root")-$sub"
  name="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')"
  t="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  git -C "$root" archive --format=tar.gz -o "$t/$name.tar.gz" "$commit" -- "$sub" || { rm -rf "$t"; die "--also: couldn't pack $sub"; }
  hash="$(sha256_of "$t/$name.tar.gz")"
  size="$(wc -c <"$t/$name.tar.gz" | tr -d ' ')"
  {
    echo "LLM-RELAY FOLDER"
    echo "repository: $(basename "$root")"
    echo "folder: $sub"
    echo "branch: $branch"
    echo "source: $SCAN_SOURCE"
    echo "commit: $commit"
    echo "taken: $(now)"
    echo "archive: $name.tar.gz, plain files with no git history"
    echo "archive sha256: $hash"
    echo "archive bytes: $size"
  } >"$t/$name.txt"
  dest="$COWORK/relay/scans"
  mkdir -p "$dest" && cp "$t/$name.tar.gz" "$dest/" && cp "$t/$name.txt" "$dest/" || { rm -rf "$t"; die "--also: couldn't copy to $dest"; }
  rm -rf "$t"
  echo "Scanned the $sub folder of $(basename "$root"): $branch at $commit, from $SCAN_SOURCE, $size bytes" >&2
  echo "Documents/Cowork/relay/scans/$name.txt"
}

# ---- mr ----------------------------------------------------------------------

# json_get <file> <dotted.key>: one value on one line, or nothing. Lists use their first item.
json_get() {
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import json, sys
v = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    if isinstance(v, list):
        v = v[0] if v else {}
    v = v.get(k) if isinstance(v, dict) else None
if v is not None:
    print(" ".join(str(v).split()))
PY
}

ticket_of() {
  python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
for f in ("title", "source_branch", "description"):
    m = re.search(r"[A-Z]+-[0-9]+", str(d.get(f) or ""))
    if m:
        print(m.group(0))
        break
PY
}

# related_refs <view.json> <host> <project> <iid>: the merge requests the description links, as
# "project iid" lines, because a review needs their discussions too. A link can be a bare !12,
# which is this project's, or name another project by its address or as group/project!12. The
# text of a link, as in [!12](address), is not a reference of its own. A line that starts with
# "host:" is a link to another GitLab, which is noted and never fetched.
related_refs() {
  python3 - "$@" <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open(sys.argv[1]))
host, project, iid = sys.argv[2], sys.argv[3], sys.argv[4]
text = str(d.get("description") or "")
seen, elsewhere = [], []
def add(p, n):
    if (p, n) != (project, iid) and (p, n) not in seen:
        seen.append((p, n))
text = re.sub(r"\[[^\]]*\]\(\s*(https?://[^)\s]+)[^)]*\)", r" \1 ", text)
url = re.compile(r"https?://([A-Za-z0-9.:-]+)/([A-Za-z0-9._/-]+?)/-/merge_requests/([0-9]+)")
for h, p, n in url.findall(text):
    if h == host:
        add(p.strip("/"), n)
    elif (h, p, n) not in elsewhere:
        elsewhere.append((h, p, n))
text = url.sub(" ", text)
short = re.compile(r"(?<![\w./-])([A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*)!([0-9]+)")
for p, n in short.findall(text):
    if "/" not in p and "/" in project:
        p = project.rsplit("/", 1)[0] + "/" + p
    add(p, n)
text = short.sub(" ", text)
for n in re.findall(r"(?<![\w/])!([0-9]+)", text):
    add(project, n)
for p, n in seen[:5]:
    print(p, n)
for h, p, n in elsewhere[:5]:
    print("host:" + h, p + "!" + n)
PY
}

glab_call() {
  if [ "$MR_HOST" = gitlab.com ]; then
    glab "$@" </dev/null
  else
    GITLAB_HOST="$MR_HOST" glab "$@" </dev/null
  fi
}

# glab can start its errors with a blank line.
glab_error() { grep -v '^[[:space:]]*$' "$WORK/glab.err" | head -n 1 | sed 's/^[[:space:]]*//'; }

# parse_mr <url>: sets MR_HOST, MR_PROJECT and MR_IID.
parse_mr() {
  local rest="${1#https://}"
  rest="${rest#http://}"
  rest="${rest%%[?#]*}"
  rest="${rest%/}"
  MR_HOST="${rest%%/*}"
  rest="${rest#*/}"
  MR_PROJECT="${rest%%/-/merge_requests/*}"
  MR_IID="${rest##*/-/merge_requests/}"
  MR_IID="${MR_IID%%/*}"
  case "$MR_IID" in '' | *[!0-9]*) die "that doesn't look like a merge request's URL: $1" ;; esac
  case "$MR_PROJECT" in '' | */-/* | *[!A-Za-z0-9._/-]*) die "that doesn't look like a merge request's URL: $1" ;; esac
  case "$MR_HOST" in '' | *[!A-Za-z0-9.:-]*) die "that doesn't look like a merge request's URL: $1" ;; esac
}

# True if this checkout's origin is that project on that host, however the URL is written.
is_clone_of() {
  local u
  # Not remote get-url, which rewrites the URL if the user has an insteadOf for it.
  u="$(git -C "$1" config --get remote.origin.url 2>/dev/null)" || return 1
  u="${u%.git}"
  u="${u%/}"
  case "$u" in
    *://*) u="${u#*://}"; u="${u#*@}" ;;
    *@*:*) u="${u#*@}"; u="${u%%:*}/${u#*:}" ;;
  esac
  [ "$u" = "$MR_HOST/$MR_PROJECT" ]
}

find_clone() {
  local root d here
  here="$(git rev-parse --show-toplevel 2>/dev/null)" || here=""
  if [ -n "$here" ] && is_clone_of "$here"; then
    printf '%s' "$here"
    return 0
  fi
  while IFS= read -r root; do
    [ -d "$root" ] || continue
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if is_clone_of "${d%/.git}"; then
        printf '%s' "${d%/.git}"
        return 0
      fi
    done <<EOF
$(find "$root" -maxdepth 7 \( -name node_modules -o -name vendor -o -name .terraform \) -prune -o -type d -name .git -print -prune 2>/dev/null)
EOF
  done <<EOF
$(printf '%s\n' "$CLONES_DIRS" | tr ':' '\n')
EOF
  return 1
}

# The first part or two of a module's path say whose it is.
module_prefix() {
  case "$1" in
    github.com/* | gitlab.com/* | bitbucket.org/*) printf '%s' "$1" | cut -d/ -f1-2 ;;
    *) printf '%s' "${1%%/*}" ;;
  esac
}

# collect_modules <clone> <commit> <own prefixes>: the libraries the MR's go.mod files pin, from
# the Go module cache, so Cowork reads the versions this MR builds against. Sets MODULES_LINE.
collect_modules() {
  local clone="$1" commit="$2" prefixes="$3" f mod ver p own json dir wanted got=0 bad=0
  MODULES_LINE="no go.mod in this repository"
  MODULES_PART=""
  wanted="$WORK/modules.wanted"
  : >"$wanted"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    git -C "$clone" show "$commit:$f" >"$WORK/go.mod.one" 2>/dev/null || continue
    MODULES_LINE=""
    own="$prefixes"
    if [ -z "$own" ]; then
      own="$(module_prefix "$(sed -n 's/^module[[:space:]]*//p' "$WORK/go.mod.one" | head -n 1 | tr -d '"')")"
    fi
    awk '/^require[[:space:]]*\(/ { b = 1; next } b && /^\)/ { b = 0; next }
         b && NF >= 2 { print $1, $2 } /^require[[:space:]]+[^(]/ { print $2, $3 }' "$WORK/go.mod.one" |
      while read -r mod ver; do
        for p in $own; do
          case "$mod" in "$p" | "$p"/*) echo "$mod $ver" >>"$wanted" ;; esac
        done
      done
  done <<EOF
$(git -C "$clone" ls-tree -r --name-only "$commit" | grep -E '(^|/)go\.mod$' | grep -vE '(^|/)vendor/')
EOF
  [ -n "$MODULES_LINE" ] || MODULES_LINE="none of its dependencies are yours"
  [ -s "$wanted" ] || return 0
  if ! command -v go >/dev/null 2>&1; then
    MODULES_LINE="left out, because go isn't on this machine"
    return 0
  fi
  mkdir -p "$WORK/go-modules"
  while read -r mod ver; do
    [ -n "$mod" ] || continue
    json="$(cd "$WORK" && GOWORK=off GOFLAGS=-mod=mod go mod download -json "$mod@$ver" 2>/dev/null)"
    printf '%s' "$json" >"$WORK/module.json"
    dir="$(json_get "$WORK/module.json" Dir)"
    if [ -n "$dir" ] && [ -d "$dir" ] && mkdir -p "$WORK/go-modules/$mod@$ver" && cp -R "$dir/." "$WORK/go-modules/$mod@$ver/"; then
      echo "$mod $ver: in go-modules/$mod@$ver" >>"$WORK/go-modules/index.txt"
      got=$((got + 1))
    else
      echo "$mod $ver: couldn't be downloaded here" >>"$WORK/go-modules/index.txt"
      bad=$((bad + 1))
    fi
  done <<EOF
$(LC_ALL=C sort -u "$wanted")
EOF
  # The module cache is read-only, and the scratch folder has to be removable.
  chmod -R u+w "$WORK/go-modules"
  MODULES_LINE="$got included, $bad couldn't be downloaded, listed in go-modules/index.txt"
  MODULES_PART=go-modules
}

# want_checks <mode> <clone> <commit> <author>: whether to run this MR's checks. Sets CHECKS_LINE
# when they won't run.
want_checks() {
  local mode="$1" clone="$2" commit="$3" author="$4"
  if ! git -C "$clone" ls-tree -r --name-only "$commit" | grep -qE '(^|/)go\.mod$'; then
    CHECKS_LINE="not run, because this repository has no go.mod"
    return 1
  fi
  if ! command -v go >/dev/null 2>&1; then
    CHECKS_LINE="not run, because go isn't on this machine"
    return 1
  fi
  case "$mode" in
    yes) return 0 ;;
    no)
      CHECKS_LINE="not run, because the user chose not to"
      return 1
      ;;
  esac
  if [ "$AT_TERMINAL" != yes ]; then
    CHECKS_LINE="not run, because there was no terminal to ask at"
    return 1
  fi
  {
    echo "Run go build, vet, test and mod tidy on a temporary copy of !$MR_IID at $commit, by ${author:-an unknown author}?"
    echo "This runs that branch's code on this Mac, and sends the output to OneDrive."
  } >/dev/tty
  while :; do
    ask_key '[y]es, [n]o: ' || KEY=n
    case "$KEY" in
      y | Y) return 0 ;;
      n | N)
        CHECKS_LINE="not run, because the user chose not to"
        return 1
        ;;
    esac
  done
}

# run_check <folder> <label> <output file> <command...>: one check, under a time limit.
run_check() {
  local dir="$1" label="$2" out="$3" start="$SECONDS" rc result
  shift 3
  printf '%s: ' "$label"
  (cd "$dir" && limited "$CHECK_LIMIT" "$@") >"$out" 2>&1
  rc=$?
  CHECKS_RUN=$((CHECKS_RUN + 1))
  case "$rc" in
    0) result=passed ;;
    124)
      result="stopped after ${CHECK_LIMIT}s"
      CHECKS_BAD=$((CHECKS_BAD + 1))
      ;;
    *)
      if grep -q 'flag provided but not defined: -diff' "$out"; then
        result="skipped, because this Go has no mod tidy -diff"
        CHECKS_RUN=$((CHECKS_RUN - 1))
      else
        result="FAILED, exit $rc"
        CHECKS_BAD=$((CHECKS_BAD + 1))
      fi
      ;;
  esac
  if [ "$(wc -c <"$out")" -gt 1000000 ]; then
    tail -c 1000000 "$out" >"$out.end"
    mv "$out.end" "$out"
  fi
  echo "$result ($((SECONDS - start))s)"
  echo "$label: $result ($((SECONDS - start))s)" >>"$WORK/mr/checks/summary.txt"
}

# run_checks <commit>: go checks on a clone of the bundle, so the user's clone stays out of it and
# files they haven't committed can't change a result. Hooks are off, because a post-checkout hook
# that rewrote go.mod once spoiled every result of a real run. Sets CHECKS_LINE.
run_checks() {
  local commit="$1" tree="$WORK/checkout" hooks="$WORK/no-hooks" f d slug label changed
  CHECKS_RUN=0
  CHECKS_BAD=0
  mkdir -p "$hooks"
  if ! git -c core.hooksPath="$hooks" clone -q "$WORK/repo.bundle" "$tree" 2>/dev/null ||
    ! git -C "$tree" config core.hooksPath "$hooks" ||
    ! git -C "$tree" checkout -q --detach "$commit" 2>/dev/null; then
    CHECKS_LINE="not run, because git couldn't make a temporary copy"
    echo "Checks $CHECKS_LINE."
    return 0
  fi
  if [ -n "$(git -C "$tree" status --porcelain --untracked-files=all)" ]; then
    CHECKS_LINE="not run, because the temporary copy didn't match the commit"
    echo "Checks $CHECKS_LINE."
    return 0
  fi
  mkdir -p "$WORK/mr/checks"
  {
    echo "commit: $commit"
    echo "ran on: $(uname -sm), $(go version 2>&1 | head -n 1)"
  } >"$WORK/mr/checks/summary.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d="$(dirname "$f")"
    slug="$(printf '%s' "$d" | tr -c 'A-Za-z0-9._-' '-')"
    [ "$d" != . ] || slug=root
    label=""
    [ "$d" = . ] || label="$d: "
    run_check "$tree/$d" "${label}go build" "$WORK/mr/checks/$slug-go-build.txt" go build ./...
    run_check "$tree/$d" "${label}go vet" "$WORK/mr/checks/$slug-go-vet.txt" go vet ./...
    run_check "$tree/$d" "${label}go test" "$WORK/mr/checks/$slug-go-test.txt" go test ./...
    run_check "$tree/$d" "${label}go mod tidy -diff" "$WORK/mr/checks/$slug-go-mod-tidy.txt" go mod tidy -diff
  done <<EOF
$(git -C "$tree" ls-files | grep -E '(^|/)go\.mod$' | grep -vE '(^|/)(vendor|testdata)/')
EOF
  changed="$(git -C "$tree" status --porcelain --untracked-files=no)"
  if [ -n "$changed" ]; then
    CHECKS_BAD=$((CHECKS_BAD + 1))
    echo "Warning: the checks changed tracked files, so later results may not be of this commit:"
    printf '%s\n' "$changed" | head -n 10 | sed 's/^/  /'
    {
      echo "the checks changed tracked files, so later results may not be of this commit:"
      printf '%s\n' "$changed"
    } >>"$WORK/mr/checks/summary.txt"
  fi
  # A build or test can leave read-only files, and the scratch folder has to be removable.
  chmod -R u+w "$tree" 2>/dev/null
  rm -rf "$tree"
  CHECKS_LINE="$CHECKS_RUN run, $CHECKS_BAD failed or stopped, in mr/checks/summary.txt"
}

# local_branch_line <clone> <branch> <commit>: whether this Mac has work the review won't see.
local_branch_line() {
  local here newer
  here="$(git -C "$1" rev-parse --verify -q "refs/heads/$2")" || { echo "none here"; return 0; }
  if [ "$here" = "$3" ]; then
    echo "the same as the merge request"
  else
    newer="$(git -C "$1" rev-list --count "$3..$here" 2>/dev/null)" || newer="?"
    echo "differs, at $here, with $newer commit(s) the merge request doesn't have"
  fi
}

# Whether the person packing this wrote it, so a review knows who it's talking to.
is_yours() {
  local mine theirs
  glab_call api user --repo "$MR_PROJECT" >"$WORK/me.json" 2>/dev/null || { echo unknown; return 0; }
  mine="$(json_get "$WORK/me.json" username)"
  theirs="$(json_get "$WORK/mr/view.json" author.username)"
  if [ -z "$mine" ] || [ -z "$theirs" ]; then
    echo unknown
  elif [ "$mine" = "$theirs" ]; then
    echo yes
  else
    echo no
  fi
}

# pack_mr <url> <repo override> <no-wiki flag> <go prefixes> <also notes> <checks mode>: one MR, in OneDrive.
pack_mr() {
  local url="$1" repo_arg="$2" no_wiki="$3" prefixes="$4" also_notes="$5" checks_mode="$6" local_line yours clone repo name ticket source target head base start commit page out n hash size dest review rp rf existing=none
  parse_mr "$url"
  repo="${MR_PROJECT##*/}"
  name="$(printf '%s-%s' "$repo" "$MR_IID" | tr -c 'A-Za-z0-9._-' '-')"
  if [ -n "$repo_arg" ]; then
    clone="$(git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null)" || die "--repo: not a git repository: $repo_arg"
  else
    clone="$(find_clone)" || die "no clone of $MR_PROJECT under $CLONES_DIRS. Name it with --repo PATH, or add the folder that holds it to where the relay looks: relay setup --clones '$CLONES_DIRS:FOLDER'"
  fi

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  trap cleanup EXIT
  mkdir -p "$WORK/mr"
  glab_call mr view "$MR_IID" -R "$MR_PROJECT" -F json >"$WORK/mr/view.json" 2>"$WORK/glab.err" ||
    die "glab couldn't read $url: $(glab_error). Check: glab auth status"
  glab_call mr diff "$MR_IID" -R "$MR_PROJECT" --raw >"$WORK/mr/diff.patch" 2>"$WORK/glab.err" ||
    die "glab couldn't read that merge request's diff: $(glab_error)"
  glab_call api "projects/:fullpath/merge_requests/$MR_IID/versions" --repo "$MR_PROJECT" >"$WORK/mr/versions.json" 2>"$WORK/glab.err" ||
    die "glab couldn't read that merge request's versions: $(glab_error)"
  # Page through, because a long review can have more than one page of discussions.
  page=1
  while [ "$page" -le 20 ]; do
    out="$WORK/mr/discussions-$page.json"
    glab_call api "projects/:fullpath/merge_requests/$MR_IID/discussions?per_page=100&page=$page" --repo "$MR_PROJECT" >"$out" 2>"$WORK/glab.err" ||
      die "glab couldn't read that merge request's discussions: $(glab_error)"
    if [ "$(tr -d '[:space:]' <"$out")" = "[]" ]; then
      [ "$page" -eq 1 ] || rm -f "$out"
      break
    fi
    page=$((page + 1))
  done
  # Each one is fetched from its own project, and the note says which file holds it, so a
  # reviewer never takes another project's merge request of the same number for it.
  : >"$WORK/related.txt"
  while read -r rp n; do
    [ -n "$n" ] || continue
    case "$rp" in
      host:*)
        echo "  ${rp#host:}/$n: on another GitLab, so not fetched" >>"$WORK/related.txt"
        continue
        ;;
    esac
    rf="related-$(printf '%s' "$rp" | tr '/' '-')-$n-discussions.json"
    if glab_call api "projects/:fullpath/merge_requests/$n/discussions?per_page=100" --repo "$rp" >"$WORK/mr/$rf" 2>/dev/null; then
      echo "  $rp!$n: mr/$rf" >>"$WORK/related.txt"
    else
      rm -f "$WORK/mr/$rf"
      echo "  $rp!$n: glab couldn't read it, so it isn't here" >>"$WORK/related.txt"
    fi
  done <<EOF
$(related_refs "$WORK/mr/view.json" "$MR_HOST" "$MR_PROJECT" "$MR_IID")
EOF

  source="$(json_get "$WORK/mr/view.json" source_branch)"
  target="$(json_get "$WORK/mr/view.json" target_branch)"
  head="$(json_get "$WORK/mr/versions.json" head_commit_sha)"
  base="$(json_get "$WORK/mr/versions.json" base_commit_sha)"
  start="$(json_get "$WORK/mr/versions.json" start_commit_sha)"
  [ -n "$source" ] && [ -n "$target" ] || die "glab's answer about $url had no branch names"
  git check-ref-format --branch "$source" >/dev/null 2>&1 || die "not a branch name: $source"
  git check-ref-format --branch "$target" >/dev/null 2>&1 || die "not a branch name: $target"
  ticket="$(ticket_of "$WORK/mr/view.json")"
  [ -n "$ticket" ] || ticket=no-ticket
  review="$ticket/$name.md"

  # Only fetches in the clone, which can hold uncommitted work. The merge request's own ref
  # works for forks too, where origin has no branch of that name.
  GIT_TERMINAL_PROMPT=0 git -C "$clone" fetch -q origin "+refs/heads/$target:refs/remotes/origin/$target" 2>/dev/null ||
    echo "Couldn't fetch $target from origin, so it's as of your last fetch." >&2
  if GIT_TERMINAL_PROMPT=0 git -C "$clone" fetch -q origin "+refs/merge-requests/$MR_IID/head:refs/remotes/origin/merge-requests/$MR_IID" 2>/dev/null; then
    SCAN_REF="refs/remotes/origin/merge-requests/$MR_IID"
  else
    GIT_TERMINAL_PROMPT=0 git -C "$clone" fetch -q origin "+refs/heads/$source:refs/remotes/origin/$source" 2>/dev/null ||
      echo "Couldn't fetch $source from origin, so it's as of your last fetch." >&2
    SCAN_REF="refs/remotes/origin/$source"
  fi
  commit="$(git -C "$clone" rev-parse --verify -q "$SCAN_REF")" || die "can't find $source in $clone, on origin or as a merge request"
  git -C "$clone" rev-parse --verify -q "refs/remotes/origin/$target" >/dev/null || die "can't find $target in $clone"

  git init -q --bare "$WORK/branch.git" || die "git couldn't make a scratch repository"
  scratch_fetch "$clone" "$WORK/branch.git" "$SCAN_REF" "refs/heads/$source" || die "git couldn't read $source from $clone"
  scratch_fetch "$clone" "$WORK/branch.git" "refs/remotes/origin/$target" "refs/heads/$target" || die "git couldn't read $target from $clone"
  git -C "$WORK/branch.git" symbolic-ref HEAD "refs/heads/$source"
  git -C "$WORK/branch.git" bundle create -q "$WORK/repo.bundle" HEAD "refs/heads/$source" "refs/heads/$target" || die "git couldn't bundle $source and $target"
  rm -rf "$WORK/branch.git"

  if [ -f "$REVIEWS_DIR/$review" ]; then
    cp "$REVIEWS_DIR/$review" "$WORK/mr/existing-review.md" || die "couldn't read $REVIEWS_DIR/$review"
    existing="yes, in mr/existing-review.md. Keep the user's edits to it"
  fi
  collect_modules "$clone" "$commit" "$prefixes"
  collect_wiki "$clone" "$repo" "$no_wiki"
  if want_checks "$checks_mode" "$clone" "$commit" "$(json_get "$WORK/mr/view.json" author.name)"; then
    run_checks "$commit"
  fi

  local_line="$(local_branch_line "$clone" "$source" "$commit")"
  yours="$(is_yours)"

  make_archive "$WORK/$name.tar.gz" -C "$WORK" repo.bundle mr ${MODULES_PART:+"$MODULES_PART"} ${WIKI_PART:+"$WIKI_PART"} || die "tar couldn't make the archive"
  hash="$(sha256_of "$WORK/$name.tar.gz")"
  size="$(wc -c <"$WORK/$name.tar.gz" | tr -d ' ')"
  {
    echo "LLM-RELAY MERGE REQUEST"
    echo "url: $url"
    echo "project: $MR_PROJECT"
    echo "iid: $MR_IID"
    echo "title: $(json_get "$WORK/mr/view.json" title)"
    echo "author: $(json_get "$WORK/mr/view.json" author.name)"
    echo "your merge request: $yours"
    echo "ticket: $ticket"
    echo "source branch: $source"
    echo "target branch: $target"
    echo "head: ${head:-unknown}"
    echo "base: ${base:-unknown}"
    echo "start: ${start:-unknown}"
    echo "commit: $commit"
    [ -z "$head" ] || [ "$head" = "$commit" ] || echo "warning: the branch in the archive is at $commit, but GitLab says the merge request's head is $head"
    echo "taken: $(now)"
    echo "clone: $clone"
    echo "local branch: $local_line"
    echo "wiki: $WIKI_LINE"
    echo "go modules: $MODULES_LINE"
    echo "changed files: $(grep -c '^diff --git' "$WORK/mr/diff.patch")"
    if [ -s "$WORK/related.txt" ]; then
      echo "merge requests the description links, each from its own project:"
      cat "$WORK/related.txt"
    fi
    echo "checks: $CHECKS_LINE"
    echo "earlier review: $existing"
    echo "review goes in the deliverable at: reviews/$review"
    if [ -n "$also_notes" ]; then
      echo "other repositories, each with a note like this one:"
      printf '%s\n' "$also_notes" | sed 's/^/  /'
    fi
    echo "tools on this machine:"
    list_tools
    echo "archive: $name.tar.gz"
    echo "archive sha256: $hash"
    echo "archive bytes: $size"
  } >"$WORK/$name.txt"
  dest="$COWORK/relay/mrs"
  mkdir -p "$dest" || die "can't create $dest"
  cp "$WORK/$name.tar.gz" "$dest/" || die "couldn't copy the archive to $dest"
  cp "$WORK/$name.txt" "$dest/" || die "couldn't copy the note to $dest"
  echo "Packed $MR_PROJECT !$MR_IID: $source at $commit, against $target, $size bytes"
  [ -z "$WIKI_PART" ] || echo "Included the $WIKI_NAME wiki (compiled pages: $WIKI_PAGES, no raw notes). Add --no-wiki to leave it out."
  [ -z "$MODULES_PART" ] || echo "Go modules: $MODULES_LINE"
  echo "Checks: $CHECKS_LINE"
  [ "$existing" = none ] || echo "Included your earlier review, $REVIEWS_DIR/$review"
  [ -z "$head" ] || [ "$head" = "$commit" ] || echo "Warning: the branch here is at $commit, but GitLab says the merge request's head is $head."
  case "$local_line" in differs*) echo "Warning: your local $source $local_line. Cowork will review $commit, so push first if you want the rest reviewed." ;; esac
  size_warning "$size"
  echo "Sent to OneDrive: Documents/Cowork/relay/mrs/$name.txt and $name.tar.gz"
}

cmd_mr() {
  local urls="" also="" also_notes="" repo_arg="" no_wiki="" prefixes="" checks="" url spec note prompt names=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --also)
        [ -n "${2:-}" ] || die "--also needs a path"
        also="$also$2
"
        shift 2
        ;;
      --repo)
        [ -n "${2:-}" ] || die "--repo needs a path"
        repo_arg="$2"
        shift 2
        ;;
      --go-prefix)
        [ -n "${2:-}" ] || die "--go-prefix needs a module prefix"
        prefixes="$prefixes $2"
        shift 2
        ;;
      --checks) checks=yes; shift ;;
      --no-checks) checks=no; shift ;;
      --no-wiki) no_wiki=1; shift ;;
      -h | --help) usage; return 0 ;;
      -*) die "relay mr: unknown option $1. Try relay --help" ;;
      *)
        urls="$urls$1
"
        shift
        ;;
    esac
  done
  [ -n "$urls" ] || die "relay mr needs a merge request's URL"
  command -v glab >/dev/null 2>&1 || die "relay mr needs glab"
  command -v python3 >/dev/null 2>&1 || die "relay mr needs python3"
  SKILLS_CHECKED=1
  check_own_skill
  sync_skills quiet
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    parse_mr "$url"
    names="$names$(printf '%s-%s' "${MR_PROJECT##*/}" "$MR_IID" | tr -c 'A-Za-z0-9._-' '-')
"
  done <<EOF
$urls
EOF
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    note="$(send_also "$spec")" || exit 1
    also_notes="$also_notes$note
"
  done <<EOF
$also
EOF
  also_notes="${also_notes%
}"
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    (pack_mr "$url" "$repo_arg" "$no_wiki" "$prefixes" "$also_notes" "$checks") || exit 1
  done <<EOF
$urls
EOF
  prompt="Use remote-pair-run to review this merge request, following its section on merge requests. With no attachment, read these notes from my OneDrive, and get the archives they name:"
  while IFS= read -r note; do
    [ -n "$note" ] || continue
    prompt="$prompt
- Documents/Cowork/relay/mrs/$note.txt"
  done <<EOF
$names
EOF
  prompt="$prompt
If I have a skill for reviewing merge requests, follow all of it for the review and the file it writes. Finish with a verdict: are these changes solid, and what has to change before this merges? Say what you didn't cover. When a finding depends on running the code, or you need another repository or config, ask me, with one line on why."
  echo
  if command -v pbcopy >/dev/null 2>&1 && printf '%s\n' "$prompt" | pbcopy 2>/dev/null; then
    echo "Paste this into Cowork. It's on your clipboard:"
  else
    echo "Paste this into Cowork:"
  fi
  echo
  printf '%s\n' "$prompt"
}

# ---- review ------------------------------------------------------------------

# Cowork names the files, so each has to be reviews/<ticket>/<name>.md, and nothing else.
review_files() {
  local p t f
  while IFS= read -r p; do
    case "$p" in
      reviews/*)
        t="${p#reviews/}"
        f="${t#*/}"
        t="${t%%/*}"
        case "$t" in '' | .* | *[!A-Za-z0-9._-]*) die "a review can't go at $p" ;; esac
        case "$f" in '' | .* | */* | *[!A-Za-z0-9._-]*) die "a review can't go at $p" ;; *.md) ;; *) die "a review can't go at $p" ;; esac
        echo "$t/$f"
        ;;
    esac
  done <<EOF
$(manifest_paths "$1")
EOF
}

# A review of an old head can still be worth keeping, so this warns and goes on.
warn_if_moved() {
  local f="$1" note old_sha now_sha
  note="$COWORK/relay/mrs/${f##*/}"
  note="${note%.md}.txt"
  [ -f "$note" ] && command -v glab >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || return 0
  old_sha="$(sed -n 's/^commit: //p' "$note" 2>/dev/null | head -n 1)"
  parse_mr "$(sed -n 's/^url: //p' "$note" 2>/dev/null | head -n 1)" 2>/dev/null || return 0
  glab_call mr view "$MR_IID" -R "$MR_PROJECT" -F json >"$WORK/now.json" 2>/dev/null || return 0
  now_sha="$(json_get "$WORK/now.json" sha)"
  [ -z "$now_sha" ] || [ -z "$old_sha" ] || [ "$now_sha" = "$old_sha" ] ||
    echo "Warning: ${f##*/} reviews $old_sha, but the merge request is now at $now_sha."
}

# What Cowork says it skipped has to be seen before saving. It comes from the cloud, so control
# characters don't reach the terminal.
show_coverage() {
  local file="$1" name="$2"
  if ! grep -qE '^##+ Coverage' "$file"; then
    echo "Warning: $name has no Coverage section, so you can't tell what Cowork skipped. Ask it to add one."
    return 0
  fi
  echo "What $name says it covered:"
  awk '/^##+ Coverage/ { on = 1; next } on && /^#/ { exit } on' "$file" | sed '/^[[:space:]]*$/d' | head -n 30 | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/^/  /'
}

cmd_review() {
  local named="" where="" expect="" copy version a task f files dest
  while [ $# -gt 0 ]; do
    case "$1" in
      --expect)
        [ -n "${2:-}" ] || die "--expect needs a version"
        expect="$2"
        shift 2
        ;;
      -h | --help) usage; return 0 ;;
      -*) die "relay review: unknown option $1. Try relay --help" ;;
      *)
        [ -z "$where" ] || die "relay review takes one deliverable"
        where="$1"
        shift
        ;;
    esac
  done
  [ -n "$where" ] || die "relay review needs a deliverable, as TASK-FOLDER/DELIVERABLE"
  named="$(deliverable_path "$where")" || exit 1
  needs_terminal review
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  trap cleanup EXIT
  copy="$WORK/deliverable"
  RUNLIB_EXPECT="$expect"
  RUNLIB_NEEDS=""
  wait_for_deliverable "$named" "$copy" || return 1
  version="$(_runlib_manifest_version "$copy/manifest.txt")"
  a="${SRC%/*}"
  task="$(basename "${a%/*}")"
  files="$(review_files "$copy")" || exit 1
  [ -n "$files" ] || die "that deliverable has nothing under reviews/"
  echo
  echo "Deliverable: $task/$(basename "$SRC")"
  echo "Version:     $version"
  echo "Saving to:   $REVIEWS_DIR"
  while IFS= read -r f; do
    if [ -f "$REVIEWS_DIR/$f" ]; then
      echo "  $f ($(wc -c <"$copy/reviews/$f" | tr -d ' ') bytes, replaces yours, which is kept as ${f##*/}.previous)"
    else
      echo "  $f ($(wc -c <"$copy/reviews/$f" | tr -d ' ') bytes, new)"
    fi
    warn_if_moved "$f"
    show_coverage "$copy/reviews/$f" "${f##*/}"
    check_skill_stamps "$copy/reviews/$f"
  done <<EOF
$files
EOF
  echo
  if ! ask_to_run "$copy" "Save it?"; then
    echo "Nothing was saved."
    return 1
  fi
  while IFS= read -r f; do
    dest="$REVIEWS_DIR/$f"
    mkdir -p "$(dirname "$dest")" || die "can't create $(dirname "$dest")"
    if [ -f "$dest" ] && ! cmp -s "$dest" "$copy/reviews/$f"; then
      cp "$dest" "$dest.previous" || die "couldn't keep your copy of $dest, so nothing replaced it"
    fi
    cp "$copy/reviews/$f" "$dest" || die "couldn't save $dest"
    echo "Saved: $dest"
    [ ! -f "$dest.previous" ] || echo "Your earlier copy: $dest.previous"
  done <<EOF
$files
EOF
}

# ---- apply -------------------------------------------------------------------

cmd_apply() {
  local named="" where="" expect="" repo_arg="" root copy version a task p patches="" done_list="" report winner=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --expect)
        [ -n "${2:-}" ] || die "--expect needs a version"
        expect="$2"
        shift 2
        ;;
      --repo)
        [ -n "${2:-}" ] || die "--repo needs a path"
        repo_arg="$2"
        shift 2
        ;;
      -h | --help) usage; return 0 ;;
      -*) die "relay apply: unknown option $1. Try relay --help" ;;
      *)
        [ -z "$where" ] || die "relay apply takes one deliverable"
        where="$1"
        shift
        ;;
    esac
  done
  [ -n "$where" ] || die "relay apply needs a deliverable, as TASK-FOLDER/DELIVERABLE"
  [ -n "$repo_arg" ] || die "relay apply needs --repo PATH, the repository to change"
  root="$(git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null)" || die "--repo: not a git repository: $repo_arg"
  named="$(deliverable_path "$where")" || exit 1
  needs_terminal apply
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  trap cleanup EXIT
  copy="$WORK/deliverable"
  RUNLIB_EXPECT="$expect"
  RUNLIB_NEEDS=""
  wait_for_deliverable "$named" "$copy" || return 1
  version="$(_runlib_manifest_version "$copy/manifest.txt")"
  a="${SRC%/*}"
  task="$(basename "${a%/*}")"
  report="$(last_run_report "$copy/manifest.txt")"
  # A deliverable with attempts carries several ways of doing it, and only the one a run proved
  # is applied. The report this Mac kept from its run of these files says which. The copy in
  # OneDrive is never read for it.
  if manifest_paths "$copy" | grep -q '^attempts/.*\.patch$'; then
    [ -n "$report" ] || die "that deliverable has attempts, and no run of version $version says which passed. Run it first: relay run $where --expect $version"
    tail -n 1 "$report" | grep -q ' RUN: PASS$' || die "the last run of version $version didn't pass, so no attempt is proven and nothing is applied. Its report: $report"
    winner="$(sed -n 's/^attempt passed: //p' "$report" | tail -n 1)"
    case "$winner" in
      '') die "the last run of version $version names no attempt that passed, so there's nothing proven to apply. Its report: $report" ;;
      .* | *[!A-Za-z0-9._-]*) die "the report names an attempt the relay can't use. Its report: $report" ;;
    esac
  fi
  patches="$(_runlib_attempt_patches "$copy" "$winner")"
  [ -n "$patches" ] || die "that deliverable has no patches"
  patches="$patches
"
  echo
  echo "Deliverable: $task/$(basename "$SRC")"
  echo "Version:     $version"
  echo "Repository:  $root, on $(git -C "$root" symbolic-ref -q --short HEAD || echo 'a detached HEAD')"
  [ -z "$winner" ] || echo "Attempt:     $winner, the one that passed"
  echo "Patches:"
  printf '%s' "$patches" | sed 's/^/  /'
  # A patch that never passed a run can still be what someone wants, but they should know.
  if [ -z "$report" ]; then
    echo "Warning: there's no report from a run of version $version on this Mac."
  elif ! tail -n 1 "$report" | grep -q ' RUN: PASS$'; then
    echo "Warning: the last run of version $version didn't pass."
  fi
  echo
  if ! ask_to_run "$copy" "Apply it, uncommitted?"; then
    echo "Nothing changed."
    return 1
  fi
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if git -C "$root" apply "$copy/$p"; then
      done_list="$p
$done_list"
    else
      echo "$p doesn't apply, so I'm undoing the rest and leaving the repository as it was." >&2
      while IFS= read -r a; do
        [ -n "$a" ] || continue
        git -C "$root" apply -R "$copy/$a" || echo "Couldn't undo $a. Check the repository with git status." >&2
      done <<EOF
$done_list
EOF
      return 1
    fi
  done <<EOF
$patches
EOF
  echo "Applied, and nothing is committed. Look it over with: git -C $root diff"
  git -C "$root" status --short
}

# ---- skills ------------------------------------------------------------------

# The user's own Claude skills, copied to Cowork with a note on top. The copy is made here every
# time, so the user's skill is the only source, and a stamp in the copy says what it was made
# from. design-and-decisions/skill-sync.md has the reasons.

# skill_files <folder>: its files, as sorted relative paths. Dotfiles stay out.
skill_files() {
  (cd "$1" 2>/dev/null && find . -type f ! -name '.*' ! -path '*/.*' | sed 's|^\./||' | LC_ALL=C sort)
}

# folder_hash <folder>: one hash for every file in it. A SKILL.md's stamp line doesn't count, so
# a copy's hash can sit in its own stamp.
folder_hash() {
  local dir="$1" f list="$SKILL_TMP/hash.list" one="$SKILL_TMP/hash.one"
  : >"$list"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$f" = SKILL.md ]; then
      grep -v '^<!-- relay:stamp ' "$dir/$f" >"$one"
      echo "$(sha256_of "$one")  $f" >>"$list"
    else
      echo "$(sha256_of "$dir/$f")  $f" >>"$list"
    fi
  done <<EOF
$(skill_files "$dir")
EOF
  sha256_of "$list"
}

# stamp_field <SKILL.md> <field>: one value from a copy's stamp line.
stamp_field() {
  sed -n 's/^<!-- relay:stamp \(.*\) -->$/\1/p' "$1" 2>/dev/null | head -n 1 | tr '|' '\n' | sed -n "s/^ *$2 \([^ ]*\) *\$/\1/p" | head -n 1
}

# header_end <SKILL.md>: the line its header ends on, or 0 if it has none.
header_end() {
  awk '{ l = $0; sub(/\r$/, "", l) }
       NR == 1 && l != "---" { print 0; found = 1; exit }
       NR > 1 && l == "---" { print NR; found = 1; exit }
       END { if (!found) print 0 }' "$1"
}

# skill_note <name> <source folder> <source hash> <stamp line>: the note that goes on top of a copy.
skill_note() {
  local name="$1" src="$2" sha="$3" stamp="$4" t lacks=""
  for t in $COWORK_LACKS; do
    ! grep -qw -- "$t" "$src/SKILL.md" 2>/dev/null || lacks="$lacks, \`$t\`"
  done
  ! grep -q 'mcp__' "$src/SKILL.md" 2>/dev/null || lacks="$lacks, MCP tools"
  lacks="${lacks#, }"
  echo "$SKILL_START"
  echo "**Adapted for Copilot Cowork by relay. The skill's own text, after this note, is unchanged.** It was written for Claude on the user's Mac, so read it with these changes:"
  echo
  echo "- Where it says to run \`glab\` or \`git\`, or to read a clone or a local file, use what the relay sent to \`Documents/Cowork/relay\` in the user's OneDrive, as your remote-pair-run skill describes. If you need more, ask the user for a \`relay scan\` or a \`relay mr\`."
  echo "- Skip any step that posts, comments, pushes or sends. Put what you would have sent in your reply, or in the file that step writes, and say you skipped it."
  echo "- Where it relies on memory, settings or files on the user's Mac that you can't see, say what's missing and ask."
  [ -z "$lacks" ] || echo "- It names tools you don't have here: $lacks. Say so where a step needs one. When something has to run, use the remote-pair-run loop."
  echo "- When you list the skills you used, as in a review's Coverage section, write this one as \`$name ${sha:0:8}\`."
  if [ -s "$src/COWORK.md" ]; then
    echo
    echo "From the user, for Cowork:"
    echo
    cat "$src/COWORK.md"
  fi
  echo
  echo "$stamp"
  echo "$SKILL_END"
}

# put_note <source SKILL.md> <note file> <output>: the note goes after the header, which Cowork
# reads first. head and tail keep every other byte as it was.
put_note() {
  local src="$1" note="$2" out="$3" n
  n="$(header_end "$src")"
  {
    [ "$n" -eq 0 ] || head -n "$n" "$src"
    cat "$note"
    tail -n "+$((n + 1))" "$src"
  } >"$out"
}

# copy_body <copy's SKILL.md> <output>: the copy with the relay's note taken out again.
copy_body() {
  local f="$1" out="$2" s e
  s="$(grep -n -x -F -- "$SKILL_START" "$f" 2>/dev/null | head -n 1 | cut -d: -f1)"
  e="$(grep -n -x -F -- "$SKILL_END" "$f" 2>/dev/null | head -n 1 | cut -d: -f1)"
  [ -n "$s" ] && [ -n "$e" ] && [ "$e" -gt "$s" ] || return 1
  {
    [ "$s" -le 1 ] || head -n "$((s - 1))" "$f"
    tail -n "+$((e + 1))" "$f"
  } >"$out"
}

# adapt_skill <name>: makes Cowork's copy of a skill in $SKILL_TMP/copy, within Cowork's limits.
# Prints why it can't.
adapt_skill() {
  local name="$1" src="$SKILLS_FROM/$1" out="$SKILL_TMP/copy" f sha copy_sha n=0 size total=0
  rm -rf "$out"
  mkdir -p "$out" || { echo "there's nowhere to make the copy"; return 1; }
  if grep -q '^<!-- relay:' "$src/SKILL.md" "$src/COWORK.md" 2>/dev/null; then
    echo "it already holds a note from the relay, so it looks like a copy and not your skill"
    return 1
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in SKILL.md | COWORK.md) continue ;; esac
    mkdir -p "$out/$(dirname "$f")" && cp "$src/$f" "$out/$f" || { echo "$f couldn't be copied"; return 1; }
    n=$((n + 1))
    size="$(wc -c <"$src/$f" | tr -d ' ')"
    [ "$size" -le 5242880 ] || { echo "$f is over 5 MB, Cowork's limit for one file"; return 1; }
    total=$((total + size))
  done <<EOF
$(skill_files "$src")
EOF
  [ "$n" -le 20 ] || { echo "it has $n files beside SKILL.md, and Cowork takes 20"; return 1; }
  sha="$(folder_hash "$src")"
  # Twice: the copy's hash goes in the stamp, and the stamp line is the one thing it leaves out.
  skill_note "$name" "$src" "$sha" "<!-- relay:stamp pending -->" >"$SKILL_TMP/note"
  put_note "$src/SKILL.md" "$SKILL_TMP/note" "$out/SKILL.md"
  copy_sha="$(folder_hash "$out")"
  skill_note "$name" "$src" "$sha" "<!-- relay:stamp template $SKILL_TEMPLATE | source $sha | copy $copy_sha | made $(now) -->" >"$SKILL_TMP/note"
  put_note "$src/SKILL.md" "$SKILL_TMP/note" "$out/SKILL.md"
  size="$(wc -c <"$out/SKILL.md" | tr -d ' ')"
  [ "$size" -le 1048576 ] || { echo "its SKILL.md comes to over 1 MB, Cowork's limit"; return 1; }
  [ $((total + size)) -le 10485760 ] || { echo "it comes to over 10 MB, Cowork's limit for one skill"; return 1; }
}

# copy_state <folder in Cowork's skills>: foreign, edited or intact, in COPY_STATE. Foreign means
# the relay didn't make it, and edited that it changed in OneDrive after the relay did.
copy_state() {
  local dst="$1" want
  COPY_STATE=intact
  want="$(stamp_field "$dst/SKILL.md" copy)"
  if [ -z "$want" ]; then
    COPY_STATE=foreign
  elif [ "$(folder_hash "$dst")" != "$want" ]; then
    COPY_STATE=edited
  fi
}

# skill_state <name>: where Cowork's copy of a skill stands, in SKILL_STATE, with the hash of the
# user's skill in SKILL_SHA. nosource: the user's skill isn't there. absent: there's no copy.
# foreign and edited: as copy_state says. stale: the user's skill, or the relay's note, has changed
# since the copy was made. same: in step.
skill_state() {
  local src="$SKILLS_FROM/$1" dst="$SKILLS_DIR/$1"
  SKILL_STATE=same
  SKILL_SHA=""
  if [ ! -f "$src/SKILL.md" ]; then
    SKILL_STATE=nosource
    return 0
  fi
  SKILL_SHA="$(folder_hash "$src")"
  if [ ! -e "$dst" ]; then
    SKILL_STATE=absent
    return 0
  fi
  copy_state "$dst"
  case "$COPY_STATE" in
    foreign | edited) SKILL_STATE="$COPY_STATE" ;;
    *)
      if [ "$(stamp_field "$dst/SKILL.md" source)" != "$SKILL_SHA" ] || [ "$(stamp_field "$dst/SKILL.md" template)" != "$SKILL_TEMPLATE" ]; then
        SKILL_STATE=stale
      fi
      ;;
  esac
}

# skill_matches <name>: the copy, with the relay's note taken out, is the user's skill byte for byte.
skill_matches() {
  local src="$SKILLS_FROM/$1" dst="$SKILLS_DIR/$1" f
  copy_body "$dst/SKILL.md" "$SKILL_TMP/body" && cmp -s "$SKILL_TMP/body" "$src/SKILL.md" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in SKILL.md | COWORK.md) continue ;; esac
    cmp -s "$src/$f" "$dst/$f" || return 1
  done <<EOF
$(skill_files "$src")
EOF
}

# What changed in OneDrive came from the cloud, so control characters don't reach the terminal.
show_skill_change() {
  local name="$1"
  echo "skill $name: Cowork's copy was changed in OneDrive after the relay made it. Lines starting with - are only in OneDrive's copy:"
  diff -r -u "$SKILLS_DIR/$name" "$SKILL_TMP/copy" 2>&1 | grep -v '^[-+]<!-- relay:stamp ' | grep -v '^diff -r' | head -n 60 | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed 's/^/  /'
}

# remove_dropped_skills <the list before>: Cowork's copies of skills the user has just taken off
# the list go, if the relay made them. One changed in OneDrive stays. Only names that were on
# this Mac's list are looked at, so another Mac's copies in the same OneDrive are safe.
remove_dropped_skills() {
  local name d
  [ -n "$SKILLS_DIR" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in remote-pair-run | relay-field-test | .* | *[!A-Za-z0-9._-]*) continue ;; esac
    case ":$SKILLS:" in *":$name:"*) continue ;; esac
    d="$SKILLS_DIR/$name"
    [ -d "$d" ] || continue
    copy_state "$d"
    case "$COPY_STATE" in
      intact) rm -rf "$d" && echo "skill $name: no longer named, so Cowork's copy was removed" ;;
      edited) echo "skill $name: no longer named, but its copy was changed in OneDrive, so it stays. Delete it in Finder if you don't want it." ;;
    esac
  done <<EOF
$(printf '%s\n' "$1" | tr ':' '\n')
EOF
}

# The relay's own skill in Cowork's folder should be this relay's. After an upgrade it isn't,
# until relay setup runs again, and Cowork goes on using the old one.
check_own_skill() {
  local s f
  OWN_SKILL_STATE="this relay's"
  for s in $OWN_SKILLS; do
    if [ ! -f "$SKILLS_DIR/$s/SKILL.md" ]; then
      OWN_SKILL_STATE=missing
      echo "Cowork doesn't have the $s skill yet. Run: relay setup" >&2
      return 0
    fi
    for f in "$REPO/cowork/$s"/*; do
      if ! cmp -s "$f" "$SKILLS_DIR/$s/$(basename "$f")"; then
        OWN_SKILL_STATE="not this relay's"
        echo "Cowork's copy of the $s skill isn't this relay's, so it may be out of date. Run: relay setup" >&2
        return 0
      fi
    done
  done
}

# sync_skills <setup|quiet> [the list before]: brings Cowork's copies of the named skills into
# step. Only setup asks, removes, or says that nothing changed. Returns 1 if a skill couldn't be
# brought into step.
sync_skills() {
  local mode="$1" before="${2:-}" name why rc=0
  [ -n "$SKILLS" ] || [ "$mode" = setup ] || return 0
  SKILL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in
      remote-pair-run | relay-field-test | .* | *[!A-Za-z0-9._-]*)
        echo "skill $name: not a name the relay can copy" >&2
        rc=1
        continue
        ;;
    esac
    skill_state "$name"
    case "$SKILL_STATE" in
      nosource)
        echo "skill $name: there's no $SKILLS_FROM/$name/SKILL.md, so nothing was copied" >&2
        rc=1
        continue
        ;;
      same)
        [ "$mode" != setup ] || echo "skill $name: Cowork's copy is in step (${SKILL_SHA:0:8})"
        continue
        ;;
      foreign)
        if [ "$mode" = setup ]; then
          echo "skill $name: Cowork's folder already has a skill of that name, which the relay didn't make. It's left alone." >&2
          echo "  To have the relay keep it in step with yours:" >&2
          echo "  1. See how it differs from yours: diff -r \"$SKILLS_FROM/$name\" \"$SKILLS_DIR/$name\"" >&2
          echo "  2. Your own skill's text goes to Cowork whatever you do here. Only text that's in Cowork's copy and not in yours is at stake: it's gone from Cowork once you move the folder. To keep any of it, put it in $SKILLS_FROM/$name/COWORK.md, and the relay adds it to its copy. Otherwise skip this step." >&2
          echo "  3. Move that folder out of Cowork's skills folder, and run relay setup again." >&2
        else
          echo "skill $name: Cowork's folder already has a skill of that name, which the relay didn't make. It's left alone. relay setup says what to do." >&2
        fi
        rc=1
        continue
        ;;
      edited)
        if [ "$mode" != setup ]; then
          echo "skill $name: Cowork's copy was changed in OneDrive, so it wasn't updated. relay setup shows the difference." >&2
          rc=1
          continue
        fi
        ;;
    esac
    if ! why="$(adapt_skill "$name")"; then
      echo "skill $name: not copied, because $why" >&2
      rc=1
      continue
    fi
    if [ "$SKILL_STATE" = edited ]; then
      show_skill_change "$name"
      if [ "$AT_TERMINAL" != yes ]; then
        echo "skill $name: left as it is. Run relay setup at a terminal to choose." >&2
        rc=1
        continue
      fi
      ask_key "Replace Cowork's copy with a fresh one? [y]es, [n]o: " || KEY=n
      case "$KEY" in
        y | Y) ;;
        *)
          echo "skill $name: left as it is in OneDrive"
          rc=1
          continue
          ;;
      esac
    fi
    if ! { rm -rf "${SKILLS_DIR:?}/$name" && mkdir -p "$SKILLS_DIR" && cp -R "$SKILL_TMP/copy" "$SKILLS_DIR/$name"; }; then
      echo "skill $name: couldn't write Cowork's copy to $SKILLS_DIR" >&2
      rc=1
      continue
    fi
    case "$SKILL_STATE" in
      absent) echo "skill $name: copied to Cowork (${SKILL_SHA:0:8})" ;;
      stale) echo "skill $name: Cowork's copy was out of date, so it was made again (${SKILL_SHA:0:8})" ;;
      edited) echo "skill $name: Cowork's copy replaced with a fresh one (${SKILL_SHA:0:8})" ;;
    esac
  done <<EOF
$(printf '%s\n' "$SKILLS" | tr ':' '\n')
EOF
  [ "$mode" != setup ] || remove_dropped_skills "$before"
  rm -rf "$SKILL_TMP"
  SKILL_TMP=""
  return "$rc"
}

# A review cites each adapted skill with its stamp. An old one means Cowork's session had an
# older copy than the user's skill is now.
check_skill_stamps() {
  local file="$1" name cited sha
  [ -n "$SKILLS" ] || return 0
  SKILL_TMP="$WORK"
  while IFS= read -r name; do
    [ -n "$name" ] && [ -f "$SKILLS_FROM/$name/SKILL.md" ] || continue
    cited="$(awk '/^##+ Coverage/ { on = 1; next } on && /^#/ { exit } on' "$file" | grep -o -- "$name [0-9a-f]\{8\}" | head -n 1)"
    [ -n "$cited" ] || continue
    sha="$(folder_hash "$SKILLS_FROM/$name")"
    [ "${cited##* }" = "${sha:0:8}" ] || echo "Warning: this review used an older copy of your $name skill (${cited##* }, and yours is now ${sha:0:8}). A new Cowork session picks up the current one."
  done <<EOF
$(printf '%s\n' "$SKILLS" | tr ':' '\n')
EOF
  SKILL_TMP=""
}

# relay skills: where each named skill stands. Changes nothing.
cmd_skills() {
  local name rc=0
  case "${1:-}" in
    -h | --help) usage; return 0 ;;
    "") ;;
    *) die "relay skills takes no arguments. Name the skills to copy with: relay setup --skills NAME:NAME" ;;
  esac
  if [ -z "$SKILLS" ]; then
    echo "No skills are named. Name some with: relay setup --skills NAME:NAME"
    return 0
  fi
  SKILL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    skill_state "$name"
    case "$SKILL_STATE" in
      same)
        if skill_matches "$name"; then
          echo "$name: in step. Cowork's copy is your skill plus the relay's note (${SKILL_SHA:0:8})"
          continue
        fi
        echo "$name: the copy's stamp is right, but its text isn't your skill's. relay setup makes it again."
        ;;
      stale) echo "$name: your skill has changed since Cowork's copy was made. relay setup, scan or mr updates it." ;;
      absent) echo "$name: not in Cowork's folder yet. relay setup copies it." ;;
      edited) echo "$name: Cowork's copy was changed in OneDrive. relay setup shows the difference." ;;
      foreign) echo "$name: Cowork's folder has a skill of that name, which the relay didn't make. relay setup says what to do." ;;
      nosource) echo "$name: there's no $SKILLS_FROM/$name/SKILL.md." ;;
    esac
    rc=1
  done <<EOF
$(printf '%s\n' "$SKILLS" | tr ':' '\n')
EOF
  rm -rf "$SKILL_TMP"
  SKILL_TMP=""
  return "$rc"
}

# ---- field test --------------------------------------------------------------

# relay field-test: starts a test that Cowork guides. The note is this Mac's own account of its
# setup, for Cowork to read and to put in its report. That report leaves the user's company, so
# the note holds no path, no account and no repository.
# The repository a field test changes, so nothing real is at risk. A file in it says the relay
# made it, and nothing here touches a folder without that file.
FIELD_REPO="$HOME/relay-field-test"
FIELD_REPO_LINE=""

field_git() {
  # No hooks, no signing and a fixed author: the user's git setup can't change where the test starts.
  git -C "$FIELD_REPO" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name="relay field test" -c user.email="relay-field-test@example.invalid" "$@"
}

make_field_repo() {
  if [ -e "$FIELD_REPO" ]; then
    [ -f "$FIELD_REPO/.relay-field-test" ] || die "$FIELD_REPO is there, and relay field-test didn't make it. Move it away, and run this again."
    FIELD_REPO_LINE="there already"
    return 0
  fi
  mkdir -p "$FIELD_REPO/gen" || die "can't create $FIELD_REPO"
  git init -q "$FIELD_REPO" || die "git couldn't make $FIELD_REPO"
  field_git symbolic-ref HEAD refs/heads/main
  echo "relay field-test made this repository. relay field-test --clean removes it." >"$FIELD_REPO/.relay-field-test"
  printf '# relay field test\n\nA repository for testing relay. Nothing here matters.\n' >"$FIELD_REPO/README.md"
  printf '#!/bin/sh\n# Writes the file a relay field test compares.\nmkdir -p gen\nprintf '"'"'hello\\n'"'"' >gen/hello.txt\n' >"$FIELD_REPO/generate.sh"
  chmod 755 "$FIELD_REPO/generate.sh"
  printf 'hello\n' >"$FIELD_REPO/gen/hello.txt"
  field_git add -A && field_git commit -q -m "The start of a relay field test" || die "git couldn't commit in $FIELD_REPO"
  # A second branch, for scanning one you aren't on.
  field_git checkout -q -b side &&
    printf 'side\n' >"$FIELD_REPO/side.txt" &&
    field_git add -A && field_git commit -q -m "A second branch" &&
    field_git checkout -q main || die "git couldn't make the second branch in $FIELD_REPO"
  FIELD_REPO_LINE="made now"
}

clean_field_test() {
  local f
  if [ -f "$FIELD_REPO/.relay-field-test" ]; then
    rm -rf "$FIELD_REPO" && echo "Removed ~/relay-field-test"
  elif [ -e "$FIELD_REPO" ]; then
    echo "Left ~/relay-field-test: relay field-test didn't make it."
  else
    echo "No test repository to remove."
  fi
  for f in relay/field-test/note.txt relay/scans/relay-field-test.txt relay/scans/relay-field-test.tar.gz; do
    [ ! -f "$COWORK/$f" ] || { rm -f "$COWORK/$f" && echo "Removed Documents/Cowork/$f from OneDrive"; }
  done
  rmdir "$COWORK/relay/field-test" 2>/dev/null
  echo "Cowork's task folders, and the reports under Documents/Cowork/relay, are left as they are."
}

cmd_field_test() {
  local dest note how name prompt key words stamp
  case "${1:-}" in
    -h | --help) usage; return 0 ;;
    --clean)
      [ $# -eq 1 ] || die "relay field-test --clean takes nothing else"
      clean_field_test
      return 0
      ;;
    "") ;;
    *) die "relay field-test takes --clean, or nothing" ;;
  esac
  make_field_repo
  case "$REPO" in
    */Cellar/* | */homebrew/* | */linuxbrew/*) how=homebrew ;;
    *) if [ -e "$REPO/.git" ]; then how=clone; else how=unpacked; fi ;;
  esac
  SKILL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/llm-relay.XXXXXX")" || die "can't make a scratch folder"
  check_own_skill 2>/dev/null
  dest="$COWORK/relay/field-test"
  note="$SKILL_TMP/note.txt"
  {
    echo "LLM-RELAY FIELD TEST"
    echo "taken: $(now)"
    echo "relay: $RELAY_VERSION"
    echo "installed by: $how"
    echo "runlib: $RUNLIB_VERSION"
    echo "system: $(sw_vers -productName 2>/dev/null || uname -s) $(sw_vers -productVersion 2>/dev/null || uname -r), $(uname -m)"
    echo "bash: ${BASH_VERSION%%(*}"
    echo "terminal app: ${TERM_PROGRAM:-unknown}"
    echo "at a terminal: $AT_TERMINAL"
    echo "test repository: ~/relay-field-test, $FIELD_REPO_LINE, with generate.sh and gen/hello.txt on main, and a second branch called side"
    echo "the relay's own skills in Cowork's folder: $OWN_SKILL_STATE"
    for key in reviews clones; do
      if [ -n "$(setting "$key" "")" ]; then echo "setting $key: set"; else echo "setting $key: default"; fi
    done
    if command -v wiki >/dev/null 2>&1; then echo "wiki command: yes"; else echo "wiki command: no"; fi
    if [ -z "$SKILLS" ]; then
      echo "the user's skills named for Cowork: none"
    else
      echo "the user's skills named for Cowork:"
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        skill_state "$name"
        case "$SKILL_STATE" in
          same) words="in step with the user's" ;;
          stale) words="behind the user's, which has changed since the copy was made" ;;
          edited) words="changed in Cowork's folder since the relay made it" ;;
          foreign) words="in Cowork's folder, but put there by hand, not by the relay" ;;
          absent) words="not in Cowork's folder yet" ;;
          *) words="named, but this Mac has no skill of that name" ;;
        esac
        stamp=""
        [ -z "$SKILL_SHA" ] || stamp=". The user's own is ${SKILL_SHA:0:8}"
        echo "  $name: $words$stamp"
      done <<EOF
$(printf '%s\n' "$SKILLS" | tr ':' '\n')
EOF
    fi
    echo "tools:"
    list_tools
  } >"$note"
  mkdir -p "$dest" && cp "$note" "$dest/note.txt" || { rm -rf "$SKILL_TMP"; die "couldn't write to $dest"; }
  cat "$note"
  rm -rf "$SKILL_TMP"
  SKILL_TMP=""
  echo
  echo "The test changes ~/relay-field-test, which this command made. relay field-test --clean removes it afterwards."
  echo "Sent to OneDrive: Documents/Cowork/relay/field-test/note.txt"
  [ "$OWN_SKILL_STATE" = "this relay's" ] || echo "Cowork needs this relay's skills first. Run relay setup, wait 10 minutes, and start a new Cowork session."
  prompt="Use relay-field-test to guide me through testing the relay, and write the report for its developer. With nothing attached, read Documents/Cowork/relay/field-test/note.txt from my OneDrive first."
  echo
  if command -v pbcopy >/dev/null 2>&1 && printf '%s\n' "$prompt" | pbcopy 2>/dev/null; then
    echo "Paste this into a new Cowork session. It's on your clipboard:"
  else
    echo "Paste this into a new Cowork session:"
  fi
  echo
  printf '%s\n' "$prompt"
  echo
  echo "Use Apple's Terminal, and keep to one tab. If Cowork's steps get hard to follow, send it: Use the YOUR TURN block format."
}

# ---- setup -------------------------------------------------------------------

# Prints the work OneDrive folder, or stops if there's none or several.
onedrive_folder() {
  local a found="" dir="" n=0
  for a in "$HOME"/Library/CloudStorage/OneDrive-*; do
    [ -d "$a" ] || continue
    # Cowork needs a work or school account.
    [ "$(basename "$a")" != OneDrive-Personal ] || continue
    found="$found
  $a"
    dir="$a"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || die "no work OneDrive folder in ~/Library/CloudStorage. Sign in to OneDrive, or name the folder with --dir"
  [ "$n" -eq 1 ] || die "several OneDrive folders. Name one with --dir:$found"
  printf '%s' "$dir"
}

# save_setting <key> <value>: one line of the settings file, replacing the key's last value.
save_setting() {
  mkdir -p "$(dirname "$SETTINGS")" || die "can't create $(dirname "$SETTINGS")"
  { grep -v "^$1=" "$SETTINGS" 2>/dev/null; echo "$1=$2"; } >"$SETTINGS.new" && mv "$SETTINGS.new" "$SETTINGS"
}

# One relay setting: its value now, the one you passed, or an answer at a terminal.
relay_setting() {
  local key="$1" passed="$2" default="$3" question="$4" old answer
  old="$(setting "$key" "")"
  answer="$passed"
  if [ -z "$answer" ] && [ -z "$old" ] && [ "$AT_TERMINAL" = yes ]; then
    printf '%s [%s]: ' "$question" "$default" >/dev/tty
    IFS= read -r answer </dev/tty || answer=""
    answer="${answer:-$default}"
  fi
  [ -n "$answer" ] || return 0
  # shellcheck disable=SC2088
  case "$answer" in "~/"*) answer="$HOME/${answer#"~/"}" ;; esac
  save_setting "$key" "$answer"
}

# Copies the remote pair-run skill into the OneDrive folder Copilot Cowork reads skills from.
cmd_setup() {
  local dir="$1" target reviews="" clones="" skills="" named="" skills_from="" before="$SKILLS" key value rc=0
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)
        [ -n "${2:-}" ] || die "--dir needs your OneDrive folder"
        dir="$2"
        shift 2
        ;;
      --reviews)
        [ -n "${2:-}" ] || die "--reviews needs a folder"
        reviews="$2"
        shift 2
        ;;
      --clones)
        [ -n "${2:-}" ] || die "--clones needs a folder"
        clones="$2"
        shift 2
        ;;
      --skills)
        [ -n "${2:-}" ] || die "--skills needs the names of your skills, separated by colons, or none"
        skills="$(printf '%s' "$2" | tr ',' ':')"
        named=1
        shift 2
        ;;
      --skills-from)
        [ -n "${2:-}" ] || die "--skills-from needs the folder your skills are in"
        skills_from="$2"
        shift 2
        ;;
      -h | --help)
        cat <<EOF
Usage: relay setup [--dir ONEDRIVE_FOLDER] [--reviews FOLDER] [--clones FOLDERS]
                   [--skills NAMES] [--skills-from FOLDER]

Copies the remote-pair-run skill to Documents/Cowork/skills in your work OneDrive, for
Microsoft Copilot Cowork. It finds OneDrive under ~/Library/CloudStorage. --dir names the
folder if there are several, or it syncs elsewhere. Run it again to update the skill.

--reviews is where relay review saves merge request reviews. --clones is where relay mr
looks for your clones, with several folders separated by colons. At a terminal, it asks
for each the first time.

--skills names your own Claude skills to copy to Cowork too, separated by colons, such as
mr-review:simple-english. Each copy is your skill with a note on top saying what to do
differently in Cowork, and is made again whenever your skill changes. --skills none stops
copying them, and removes the copies. --skills-from is where your skills live, if it isn't
~/.claude/skills. relay skills shows where each one stands.
EOF
        return 0
        ;;
      *) die "setup: unknown option $1. Try relay setup --help" ;;
    esac
  done
  [ -n "$dir" ] || dir="$(onedrive_folder)" || exit 1
  [ -d "$dir" ] || die "no such folder: $dir"
  for key in $OWN_SKILLS; do
    target="$dir/Documents/Cowork/skills/$key"
    mkdir -p "$target" || die "can't create $target"
    cp "$REPO/cowork/$key"/* "$target/" || die "can't copy the skill to $target"
    echo "installed: $target"
  done
  relay_setting reviews "$reviews" "$HOME/mr-reviews" "Where should merge request reviews go?"
  relay_setting clones "$clones" "$HOME/dev" "Where are your clones?"
  for key in reviews clones; do
    value="$(setting "$key" "")"
    [ -z "$value" ] || echo "relay setting: $key=$value"
  done
  if [ -n "$skills_from" ]; then
    # shellcheck disable=SC2088
    case "$skills_from" in "~/"*) skills_from="$HOME/${skills_from#"~/"}" ;; esac
    [ -d "$skills_from" ] || die "--skills-from: no such folder: $skills_from"
    SKILLS_FROM="$(cd "$skills_from" && pwd)"
    save_setting skills_from "$SKILLS_FROM"
  fi
  if [ -n "$named" ]; then
    [ "$skills" != none ] || skills=""
    SKILLS="$skills"
    save_setting skills "$SKILLS"
  fi
  SKILLS_DIR="$dir/Documents/Cowork/skills"
  sync_skills setup "$before" || rc=1
  [ -z "$SKILLS" ] || echo "relay setting: skills=$SKILLS, from $SKILLS_FROM"
  echo "Cowork finds it when a new session starts, but its copy can lag OneDrive by several minutes, so give it 10. Ask it to change code in a repository, and it will give you a relay run command. Run that in Apple's Terminal: macOS can refuse other terminal apps."
  return "$rc"
}

# ---- completion --------------------------------------------------------------

# __complete <index> <word>...: candidates for the word at index (1 is the first after relay).
cmd_complete() {
  local i="$1" prev="" sub at=1
  shift
  [ "$i" -le 1 ] || prev="$(eval "printf '%s' \"\${$((i - 1)):-}\"")"
  case "$prev" in
    --repo | --dir | --also | --clones | --reviews | --skills-from) echo __dirs__; return 0 ;;
  esac
  # --dir FOLDER can come first.
  sub="${1:-}"
  if [ "$i" -gt 1 ] && [ "$sub" = --dir ]; then sub="${3:-}"; at=3; fi
  if [ "$i" -le "$at" ]; then
    printf 'setup\nrun\nscan\nmr\nreview\napply\nskills\nfield-test\ncompletion\n'
    [ "$at" -eq 3 ] || echo --dir
    return 0
  fi
  case "$sub" in
    setup) printf -- '--dir\n--reviews\n--clones\n--skills\n--skills-from\n' ;;
    run) printf -- '--expect\n--no-install\n' ;;
    scan) printf -- '--branch\n--no-wiki\n' ;;
    mr) printf -- '--repo\n--also\n--go-prefix\n--checks\n--no-checks\n--no-wiki\n' ;;
    review) echo --expect ;;
    field-test) echo --clean ;;
    apply) printf -- '--repo\n--expect\n' ;;
    completion) printf 'zsh\nbash\n' ;;
  esac
  return 0
}

cmd_completion() {
  case "${1:-}" in
    zsh)
      cat <<'EOF'
# Tab completion for relay. Written by `relay completion zsh`.
_llm_relay() {
  local -a c
  c=("${(@f)$(${words[1]} __complete $((CURRENT - 1)) ${words[2,-1]} 2>/dev/null)}")
  if [[ "${c[1]}" == __dirs__ ]]; then _files -/; return; fi
  compadd -a c
}
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit -i; }
compdef _llm_relay relay relay.sh
EOF
      ;;
    bash)
      cat <<'EOF'
# Tab completion for relay. Written by `relay completion bash`.
_llm_relay() {
  local cur="${COMP_WORDS[COMP_CWORD]}" out
  # Set IFS only after this: bash 3.2 joins "${COMP_WORDS[@]:1}" when IFS is a newline.
  out="$("${COMP_WORDS[0]}" __complete "$COMP_CWORD" "${COMP_WORDS[@]:1}" 2>/dev/null)"
  local IFS=$'\n'
  if [ "${out%%$'\n'*}" = __dirs__ ]; then COMPREPLY=($(compgen -d -- "$cur")); return; fi
  COMPREPLY=($(compgen -W "$out" -- "$cur"))
}
complete -F _llm_relay relay relay.sh ./relay.sh
EOF
      ;;
    *) die "completion takes zsh or bash" ;;
  esac
}

# ---- dispatch ----------------------------------------------------------------

case "${1:-}" in
  __complete) shift; cmd_complete "$@"; exit 0 ;;
  completion) shift; cmd_completion "$@"; exit 0 ;;
  --version | version) echo "relay $RELAY_VERSION"; exit 0 ;;
esac

ONEDRIVE=""
if [ "${1:-}" = --dir ]; then
  [ -n "${2:-}" ] || die "--dir needs your OneDrive folder"
  ONEDRIVE="$2"
  shift 2
fi
case "${1:-}" in
  setup) shift; cmd_setup "$ONEDRIVE" "$@"; exit $? ;;
  run | scan | mr | review | apply | skills | field-test)
    command -v git >/dev/null 2>&1 || die "relay needs git"
    [ -n "$ONEDRIVE" ] || ONEDRIVE="$(onedrive_folder)" || exit 1
    [ -d "$ONEDRIVE" ] || die "no such folder: $ONEDRIVE"
    COWORK="$ONEDRIVE/Documents/Cowork"
    SKILLS_DIR="$COWORK/skills"
    ;;
esac
case "${1:-}" in
  run) shift; cmd_run "$@"; exit $? ;;
  scan) shift; cmd_scan "$@"; exit $? ;;
  mr) shift; cmd_mr "$@"; exit $? ;;
  review) shift; cmd_review "$@"; exit $? ;;
  apply) shift; cmd_apply "$@"; exit $? ;;
  skills) shift; cmd_skills "$@"; exit $? ;;
  field-test) shift; cmd_field_test "$@"; exit $? ;;
  "" | -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
