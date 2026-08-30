#!/usr/bin/env sh
# Structural check for the eval corpus. Dependency-free POSIX sh.
#
# This does NOT run VibeProof — that needs an agent and a human reading the
# output. What it does is guarantee the corpus stays honest:
#
#   · every fixture declares its ground truth
#   · every bug fixture has a paired control
#   · pairing is reciprocal, so a rename cannot orphan half a pair
#   · every control expects zero findings
#
# The third rule is the one that matters. A detector that only ever sees broken
# code will pass its own tests while flagging everything in sight. The control
# is where precision is measured, so a pair with a missing control is worse than
# no fixture at all — it looks like coverage and measures nothing.
#
# Run:  sh evals/run-check.sh

set -u

DIR=$(cd "$(dirname "$0")" && pwd)
CORPUS="$DIR/corpus"
[ -d "$CORPUS" ] || { echo "no corpus at $CORPUS"; exit 1; }

fail=0
count=0
bugs=0
controls=0

err() { fail=$((fail + 1)); printf '  FAIL  %s\n       %s\n' "$1" "$2"; }

# key <file> <name>  → prints the JSON string value, empty if absent
key() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}
has_key() { grep -q '"'"$2"'"[[:space:]]*:' "$1"; }

# Collect fixture directories: any directory holding an expected.json.
LIST=$(mktemp) || exit 1
trap 'rm -f "$LIST" "$IDS"' EXIT INT TERM
find "$CORPUS" -name expected.json | sort > "$LIST"

IDS=$(mktemp) || exit 1
while IFS= read -r f; do
  key "$f" id >> "$IDS"
done < "$LIST"

echo "eval corpus check"

while IFS= read -r f; do
  d=$(dirname "$f")
  name=$(basename "$d")
  count=$((count + 1))

  id=$(key "$f" id)
  kind=$(key "$f" kind)
  pair=$(key "$f" pairs_with)

  [ -n "$id" ] || { err "$name" "expected.json has no id"; continue; }
  [ "$id" = "$name" ] || err "$name" "id is \"$id\" but the directory is \"$name\""

  case $kind in
    bug) bugs=$((bugs + 1)) ;;
    control) controls=$((controls + 1)) ;;
    *) err "$name" "kind must be bug or control, got \"$kind\"" ;;
  esac

  for k in family note pairs_with; do
    has_key "$f" "$k" || err "$name" "missing required key: $k"
  done

  # Ground truth a bug fixture must state, so a run can be scored against it.
  if [ "$kind" = "bug" ]; then
    for k in product_status evidence_max severity primary_category; do
      has_key "$f" "$k" || err "$name" "bug fixture missing: $k"
    done
  fi

  # A control that tolerates findings is not a control.
  if [ "$kind" = "control" ]; then
    if ! grep -q '"expect_findings"[[:space:]]*:[[:space:]]*0' "$f"; then
      err "$name" "control must declare \"expect_findings\": 0"
    fi
  fi

  # Pairing must resolve and be reciprocal.
  if [ -n "$pair" ]; then
    if ! grep -qx "$pair" "$IDS"; then
      err "$name" "pairs_with \"$pair\" does not exist"
    else
      pf=$(grep -l "\"id\"[[:space:]]*:[[:space:]]*\"$pair\"" $(cat "$LIST" | tr '\n' ' ') 2>/dev/null | head -1)
      back=$(key "$pf" pairs_with)
      [ "$back" = "$id" ] || err "$name" "pairing is not reciprocal: $pair points at \"$back\""
      pkind=$(key "$pf" kind)
      [ "$pkind" != "$kind" ] || err "$name" "paired with another $kind — a pair needs one bug and one control"
    fi
  fi

  # A fixture with no source is a note, not a test.
  n=$(find "$d" -type f ! -name expected.json | wc -l | tr -d ' ')
  [ "${n:-0}" -gt 0 ] || err "$name" "no source files"
done < "$LIST"

printf '\n%d fixtures · %d bugs · %d controls\n' "$count" "$bugs" "$controls"
[ "$bugs" -eq "$controls" ] || err "corpus" "every bug needs a control: $bugs bugs, $controls controls"

if [ "$fail" -gt 0 ]; then printf '%d problem(s)\n' "$fail"; exit 1; fi
echo "corpus OK"
exit 0
