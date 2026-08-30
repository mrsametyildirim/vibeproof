#!/usr/bin/env sh
# VibeProof tripwire v2 — runs after the agent finishes writing code.
#
# This is NOT the audit. It is a two-second smell test over the files that just
# changed, and it answers one question: "is it worth running the audit?"
#
# DESIGN RULE: this fires after every turn. Something that frequent must be nearly
# silent or it becomes noise and gets disabled within a day.
#   clean   → prints nothing, exits 0
#   tripped → ONE line: the count, the strongest signal, and the command to run
# It never blocks, never modifies, never prints a wall of text.
#
# Opt-in install:  ./install.sh --with-hook
# Or add to ~/.claude/settings.json:
#   "Stop": [{ "hooks": [{ "type": "command",
#              "command": "sh $HOME/.vibeproof/tripwire.sh" }] }]
#
# ── v2: three defects found in external review, all real ─────────────────────
#  1. Filenames containing whitespace were silently skipped. The file list was
#     passed unquoted to grep, so `src/a b.js` split into two paths that do not
#     exist and matched nothing. Now every file is handled one at a time through
#     `IFS= read -r`, which preserves spaces, tabs and quotes.
#  2. The fetch check compared TOTALS across all changed files, so an unrelated
#     `if (res.ok)` in one file masked a genuinely unchecked fetch in another.
#     Correlation is now per file.
#  3. "Strongest signal" kept whichever pattern matched FIRST. A hardcoded
#     credential lost to a no-op button in the same file. Signals now carry an
#     explicit priority and the highest one wins.
#
# Paths come from git as NUL-delimited (-z) and are converted to lines. This is not
# cosmetic: without -z, git C-quotes any path containing a control character or a
# non-ASCII byte, so `src/we'ird<TAB>name.js` arrives as the literal string
#   "src/we'ird	name.js"
# — quotes and backslash included — which is not a path that exists, and the file is
# silently skipped. core.quotepath=false is NOT enough; it only suppresses the
# non-ASCII escaping, never the control-character quoting. CI caught this on Linux
# and macOS after it passed locally.
#
# Known limit: a filename containing a literal newline is still skipped. Handling it
# would need `read -d ''`, a bashism, and this hook claims POSIX sh. Spaces, tabs,
# quotes and unicode all work.
#
# Portability: POSIX sh, POSIX character classes only. GNU-only regex escapes are
# rejected in CI, because BSD grep reads them as literal letters and the pattern
# then silently matches nothing on macOS.

set -u

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

SRC_EXT='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|vue|svelte|py|rb|php|go|java|kt|cs)$'

# Excluded: code that is definitionally not the product. Note what is NOT here —
# examples/ and demo/ are no longer filtered out. They are usually not product
# code, but "usually" is the wrong bar for a smell test: a missed signal means the
# audit never runs, while a false one costs a single line the user can ignore.
NOT_PRODUCT='(^|/)(tests?|spec|__tests__|__mocks__|mocks|fixtures|seeds|node_modules|vendor|dist|build|\.next|coverage)(/|$)'

# What changed — modified AND newly created.
#
# `git diff` alone misses untracked files, which is precisely the case that matters
# most: a file the agent just wrote has never been committed, so it is invisible to
# diff. Missing those would make the tripwire useless for new code.
LIST=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$LIST"' EXIT INT TERM

{ git diff -z --name-only --diff-filter=ACM HEAD 2>/dev/null
  git ls-files -z --others --exclude-standard 2>/dev/null
} | tr '\0' '\n' | sort -u \
  | grep -Ei "$SRC_EXT" \
  | grep -Eiv "$NOT_PRODUCT" \
  | grep -Eiv '\.(test|spec|stories)\.' \
  | head -60 > "$LIST"

# Deletions are tracked separately. A removed route or handler cannot be scanned
# for its contents, but deleting one is an effective way to break wiring that
# still exists elsewhere — exactly what the audit looks for.
GONE=$(git diff -z --name-only --diff-filter=D HEAD 2>/dev/null | tr '\0' '\n' \
       | grep -Ei "$SRC_EXT" \
       | grep -Eiv "$NOT_PRODUCT" \
       | grep -Eic '(^|/)(app|pages|routes?|api|controllers?|handlers?)(/|$)|/route\.|/page\.')
GONE=${GONE:-0}

if [ ! -s "$LIST" ] && [ "$GONE" -eq 0 ]; then exit 0; fi

hits=0
top=""
toprank=0

# note <count> <priority> <label>
#
# Priority is what makes "strongest signal" true rather than "first signal".
# A credential literal must outrank a dead button in the same file.
note() {
  c=${1:-0}
  [ "$c" -gt 0 ] 2>/dev/null || return 0
  hits=$((hits + c))
  if [ "$2" -gt "$toprank" ]; then toprank=$2; top=$3; fi
}

# Success announcements, across the common UI libraries. Missing these was a
# silent gap: only toast.success was recognised, so Ant Design, MUI/notistack and
# plain status setters slipped through.
RE_SUCCESS='toast\.success|toast\(["'"'"'][^"'"'"']*(saved|success|deleted|sent|updated|created)|setSuccess\([[:space:]]*true|showSuccess|notifySuccess|message\.success|notification\.success|enqueueSnackbar\(["'"'"'][^"'"'"']*(saved|success|sent)|setStatus\(["'"'"'][^"'"'"']*(success|saved|done)|alert\(["'"'"'][^"'"'"']*(saved|success|deleted|sent)'

RE_DEADUI='onClick=\{[[:space:]]*\([[:space:]]*\)[[:space:]]*=>[[:space:]]*\{[[:space:]]*\}[[:space:]]*\}|href="#"|@click="[[:space:]]*"'
RE_DESTRUCTIVE='[Dd]elete|[Rr]emove|[Dd]estroy|[Pp]ay|[Cc]heckout|[Cc]ancel[[:space:]]*[Ss]ubscription'
RE_CRED='sk_live_[A-Za-z0-9]|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}|sk-ant-[A-Za-z0-9]|AIza[0-9A-Za-z_-]{30}'
RE_LOCAL='https?://localhost|https?://127\.0\.0\.1'

# `IFS= read -r` is what makes whitespace-bearing filenames work. Redirecting from
# a file rather than piping keeps the loop in this shell, so the counters survive.
while IFS= read -r f; do
  [ -f "$f" ] || continue

  # 1. Success announced next to a call that is not awaited.
  #
  #    The preceding line must look like an OPERATION, not local bookkeeping.
  #    Without this filter the check fires on correct code: a React state setter
  #    placed before a legitimate success toast
  #        setNotes(fresh);
  #        toast.success("Deleted");
  #    is synchronous and entirely right, but matched "a call with no await".
  #    -H is required: with a single file grep omits the filename prefix, so the
  #    context lines come back as "1-code" instead of "file-1-code".
  n=$(grep -Hn -B1 -E "$RE_SUCCESS" "$f" 2>/dev/null \
      | grep -E '^[^:]+-[0-9]+-' \
      | grep -E '[a-zA-Z_$][A-Za-z0-9_.$]*\(' \
      | grep -vcE 'await|\.then\(|[[:space:]]set[A-Z]|console\.|router\.(push|replace|back)|dispatch\(|navigate\(|return[[:space:]]')
  note "${n:-0}" 90 "success reported before await"

  # 2. catch/except that produces a success value.
  n=$(grep -n -A3 -E 'catch[[:space:]]*[({]|except[ :]' "$f" 2>/dev/null \
      | grep -cE 'success["'"'"']?[[:space:]]*[:=][[:space:]]*[Tt]rue|return[[:space:]]+True|"status"[[:space:]]*:[[:space:]]*"(ok|sent|success)"')
  note "${n:-0}" 95 "catch block returning success"

  # 3. Controls wired to nothing. A dead control on a destructive action is a
  #    different class of problem from a dead "collapse sidebar" — same defect,
  #    different consequence, so it ranks higher.
  n=$(grep -cE "$RE_DEADUI" "$f" 2>/dev/null)
  if [ "${n:-0}" -gt 0 ]; then
    d=$(grep -E "$RE_DEADUI" "$f" 2>/dev/null | grep -cE "$RE_DESTRUCTIVE")
    if [ "${d:-0}" -gt 0 ]; then
      note "$n" 80 "dead control on a destructive action"
    else
      note "$n" 40 "handler that does nothing"
    fi
  fi

  # 4. Literal credential, then localhost. A live key is the most serious thing
  #    this hook can see and must never be outranked by a cosmetic finding.
  n=$(grep -cE "$RE_CRED" "$f" 2>/dev/null);  note "${n:-0}" 100 "credential literal in source"
  n=$(grep -cE "$RE_LOCAL" "$f" 2>/dev/null); note "${n:-0}" 30  "localhost URL in source"

  # 5. fetch result consumed without any status check IN THE SAME FILE.
  #
  #    v1 compared repository-wide totals, so one `res.ok` anywhere cancelled one
  #    unchecked fetch everywhere. Per-file is still coarse — two unrelated flows
  #    in one file can mask each other — but it removes the cross-file failure,
  #    and this is a smell test, not the audit.
  used=$(grep -cE 'await[[:space:]]+fetch\(' "$f" 2>/dev/null)
  chk=$(grep -cE '\.ok([^A-Za-z0-9_]|$)|\.status[[:space:]]*[=!<>]|validateStatus|throwHttpErrors' "$f" 2>/dev/null)
  if [ "${used:-0}" -gt "${chk:-0}" ]; then
    note "$(( used - chk ))" 60 "fetch result used without checking status"
  fi
done < "$LIST"

# ── Memory ───────────────────────────────────────────────────────────────────
# The tripwire remembers its last count so it can tell you when something you were
# warned about is gone. That closing note is the moment the tool proves its worth —
# without it you only ever hear complaints.
#
# It reports a FACT ("no longer present"), never credit ("fixed thanks to us").
# VibeProof did not write the fix; claiming it would be exactly the kind of small
# lie this tool exists to find.
# State lives OUTSIDE the audited repository, keyed by its root path.
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
KEY=$(printf '%s' "$REPO" | tr -c 'A-Za-z0-9' '_' | tail -c 60)
STATE_DIR="${VIBEPROOF_STATE:-$HOME/.vibeproof/state}"
STATE="$STATE_DIR/$KEY"
prev=0
[ -f "$STATE" ] && prev=$(cat "$STATE" 2>/dev/null | tr -dc '0-9') && prev=${prev:-0}

if [ "$hits" -gt 0 ]; then
  mkdir -p "$STATE_DIR" 2>/dev/null
  printf '%s' "$hits" > "$STATE" 2>/dev/null
  printf '\n\033[33m⚠ VibeProof\033[0m  %d suspicious pattern%s in the code just written (%s).\n            Run \033[1m/vibeproof diff\033[0m to verify.\n' \
    "$hits" "$([ "$hits" -eq 1 ] || printf s)" "$top"
  [ "$GONE" -gt 0 ] && printf '            %d production route/handler file%s also removed.\n' \
    "$GONE" "$([ "$GONE" -eq 1 ] || printf s)"
  exit 0
fi

# Deletions alone are not a bug — but they can break wiring that still exists, and
# the hook cannot scan a file that is gone. Say only that much.
if [ "$GONE" -gt 0 ]; then
  printf '\n\033[33m⚠ VibeProof\033[0m  %d production route/handler file%s removed.\n            Wiring elsewhere may now be broken — run \033[1m/vibeproof diff\033[0m.\n' \
    "$GONE" "$([ "$GONE" -eq 1 ] || printf s)"
  exit 0
fi

# Nothing trips now. Say something only if something tripped before.
if [ "$prev" -gt 0 ]; then
  rm -f "$STATE" 2>/dev/null
  # Cumulative ledger — how much this tool has actually caught over time.
  total=0
  [ -f "$STATE.cleared" ] && total=$(cat "$STATE.cleared" 2>/dev/null | tr -dc '0-9')
  total=$(( ${total:-0} + prev ))
  mkdir -p "$STATE_DIR" 2>/dev/null
  printf '%s' "$total" > "$STATE.cleared" 2>/dev/null
  printf '\n\033[32m✓ VibeProof\033[0m  %d flagged pattern%s no longer present. (%d cleared in this repo.)\n' \
    "$prev" "$([ "$prev" -eq 1 ] || printf s)" "$total"
fi
exit 0
