#!/usr/bin/env bash
# gallery.sh: what the relay's commands print at a terminal, kept as golden files, so a change
# to the look shows up in review and a command still on the old look stands out. llm-wiki has
# the same for wiki; docs/conventions.md has the rules.
#
#   scripts/gallery.sh            render the commands into tests/gallery/ and write its index
#   scripts/gallery.sh --check    render into a temp folder and fail on any difference
#
# The relay styles only at a terminal, so each command runs at a pseudo-terminal through
# tests/type-keys.py, against fakes in a temp folder with its own HOME: a OneDrive folder, a
# repository with a branch, and a clipboard. UTF-8, the 16 colours, 80 columns. Temp paths,
# dates, times, commit hashes, sizes and the relay's version are replaced by placeholders, so a
# file changes only when what the command prints does. The index, tests/gallery/README.md, says
# which of the kit's pieces each command used: "kit", "old look", "mixed" or "unstyled".
# Commands that need GitLab, Jira or a deliverable from Copilot Cowork (mr, ticket, run,
# review, apply, ask, answer) aren't rendered here: the smoke test's fakes cover them.
# Needs python3. The files are made on macOS, the relay's home: on Linux some messages differ,
# such as how to install a tool, so the smoke test checks the gallery on macOS only.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$REPO/relay.sh"
OUT="$REPO/tests/gallery"
check=no
case "${1:-}" in
  "") ;;
  --check) check=yes ;;
  -h | --help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' && exit 0 ;;
  *) printf 'error: no option %s. Run: scripts/gallery.sh --help\n' "$1" >&2 && exit 2 ;;
esac
T="$(mktemp -d)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT
DEST="$OUT"
[ "$check" = no ] || DEST="$T/gallery"
rm -rf "$DEST.new" && mkdir -p "$DEST.new"

# The fakes. No wiki command: the relay has to work without llm-wiki.
export HOME="$T/home" TZ=UTC LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TERM=xterm COLUMNS=80
unset XDG_CONFIG_HOME NO_COLOR COLORTERM COLORFGBG LLM_PALETTE LLM_THEME LLM_RELAY_STYLE WIKIS_DIR
OD="$HOME/Library/CloudStorage/OneDrive-Example"
mkdir -p "$OD/Documents/Cowork" "$HOME/.config/llm-relay" "$T/bin" "$HOME/dev"
printf 'reviews=%s\nclones=%s\npalette=default\ntheme=auto\n' "$HOME/mr-reviews" "$HOME/dev" >"$HOME/.config/llm-relay/settings"
printf '#!/bin/sh\ncat >"%s/clipboard"\n' "$T" >"$T/bin/pbcopy"
chmod +x "$T/bin/pbcopy"
PATH="$T/bin:/usr/bin:/bin"
for d in /opt/homebrew/bin /usr/local/bin; do
  [ -x "$d/python3" ] && PATH="$PATH:$d"
done
export PATH
git config --global user.email gallery@example.test
git config --global user.name Gallery
git config --global init.defaultBranch main
SVC="$HOME/dev/svc"
git init -q --bare "$T/svc.git"
git init -q "$SVC"
printf 'package main\n' >"$SVC/main.go"
git -C "$SVC" add -A && git -C "$SVC" commit -qm start
git -C "$SVC" remote add origin "$T/svc.git" && git -C "$SVC" push -q -u origin main 2>/dev/null
git -C "$SVC" checkout -q -b ABC-12-work
printf 'package main\n\nfunc main() {}\n' >"$SVC/main.go"
git -C "$SVC" commit -qam 'ABC-12 the work'
cd "$SVC" || exit 1

# normalize: the parts of a run that change from one run to the next.
normalize() {
  LC_ALL=C sed -E -e "s#$T#<tmp>#g" -e "s#$REPO#<repo>#g" -e "s#$HOME#<home>#g" -e 's/\r$//' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}/YYYY-MM-DD/g' -e 's/[0-9]{2}:[0-9]{2}(:[0-9]{2})?/HH:MM/g' \
    -e 's/[0-9a-f]{40}/<sha>/g' -e 's/(^|[^0-9a-zA-Z])[0-9a-f]{7,12}([^0-9a-zA-Z]|$)/\1<short-sha>\2/g' \
    -e 's/[0-9]+ bytes/<n> bytes/g' -e 's/([^0-9])[0-9]+s([^a-z])/\1<n>s\2/g' \
    -e "s/relay $(sed -n 's/^RELAY_VERSION="\(.*\)"$/\1/p' "$R")/relay <version>/g"
}
# look <trace> <output>: kit: the kit's pieces and nothing else; old look: version 2's helpers
# or codes of its own; mixed: both; unstyled: nothing at all. An error alone is the kit's.
look() {
  local kit=no v2=no
  grep -qv -e '^ui_typed$' -e '^ui_error$' -e '^v2$' "$1" 2>/dev/null && kit=yes
  [ "$kit" = yes ] || ! grep -q '^ui_error$' "$1" 2>/dev/null || grep -q '^v2$' "$1" || kit=yes
  grep -q '^v2$' "$1" 2>/dev/null && v2=yes
  if [ "$kit" = yes ] && [ "$v2" = yes ]; then echo mixed
  elif [ "$kit" = yes ]; then echo kit
  elif [ "$v2" = yes ] || grep -q "$(printf '\033')" "$2"; then echo "old look"
  else echo unstyled; fi
}
INDEX="$T/index"
: >"$INDEX"
# render <name> <keys> <args...>: run one command at a pseudo-terminal, typing the keys at its
# prompts, and keep what the terminal showed, and its look.
render() {
  local name="$1" keys="$2" tr="$T/trace" pieces
  shift 2
  : >"$tr"
  UI_TRACE="$tr" python3 "$REPO/tests/type-keys.py" "$keys" "$R" "$@" 2>&1 | normalize >"$DEST.new/relay-$name.txt"
  pieces="$(grep '^ui_' "$tr" | sort -u | sed 's/^ui_//' | paste -sd ' ' -)"
  printf '%s\t%s\t%s\t%s\n' "$(printf 'relay %s' "$*" | normalize)" "$(look "$tr" "$DEST.new/relay-$name.txt")" "${pieces:--}" "relay-$name.txt" >>"$INDEX"
}

render help "" --help
render setup-help "" setup --help
render setup "" setup --dir "$OD"
render start "" --dir "$OD" start
render skills "" --dir "$OD" skills
render scan "" --dir "$OD" scan "$SVC"
render branch "" --dir "$OD" branch "$SVC" --against main --no-checks --no-plan
render field-test "" --dir "$OD" field-test
render error "" nosuch

{
  echo "# Gallery"
  echo
  echo "What the relay's commands print at a terminal, made by \`scripts/gallery.sh\`. Don't edit these files: run it again. \`cat\` a file at a terminal to see the look. \`mr\`, \`ticket\`, \`run\`, \`review\`, \`apply\`, \`ask\` and \`answer\` need GitLab, Jira or a deliverable from Copilot Cowork, so the smoke test's fakes cover them instead."
  echo
  # A list with a blank line between entries, so pull requests that each move a command don't
  # touch neighbouring lines.
  awk -F '\t' '{ printf "- `%s`: %s. Pieces: %s. [%s](%s)\n\n", $1, $2, $3, $4, $4 }' "$INDEX"
} >"$DEST.new/README.md"

if [ "$check" = yes ]; then
  if diff -r "$OUT" "$DEST.new" >"$T/diff" 2>&1; then
    echo "gallery: every command prints what its file in tests/gallery has."
    exit 0
  fi
  echo "gallery: what these commands print has changed. Look at the difference, then run: scripts/gallery.sh"
  grep -E '^(diff|Only in)' "$T/diff" | sed -e "s#$T/gallery.new#new#g" -e "s#$REPO/##g"
  exit 1
fi
rm -rf "$OUT"
mv "$DEST.new" "$OUT"
old="$(awk -F '\t' '$2 != "kit" { n++ } END { print n + 0 }' "$INDEX")"
echo "gallery: $(wc -l <"$INDEX" | tr -d ' ') commands in tests/gallery/, $old of them not yet on the kit."
