#!/usr/bin/env sh
# VibeProof tripwire — runs after the agent finishes writing code.
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

set -u

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# What changed in the working tree — modified AND newly created.
#
# `git diff` alone misses untracked files, which is precisely the case that matters
# most: a file the agent just wrote has never been committed, so it is invisible to
# diff. Missing those would make the tripwire useless for new code.
FILES=$( { git diff --name-only --diff-filter=ACM HEAD 2>/dev/null;
           git ls-files --others --exclude-standard 2>/dev/null; } \
        | sort -u \
        | grep -Ei '\.(js|jsx|ts|tsx|vue|svelte|py|rb|php|go|java|kt|cs)$' \
        | grep -Eiv '(^|/)(tests?|spec|__tests__|__mocks__|mocks|fixtures|seeds|examples?|demo)(/|$)' \
        | grep -Eiv '\.(test|spec|stories)\.' \
        | head -60)
[ -n "$FILES" ] || exit 0

hits=0
top=""

count() {   # count <extended-regex>  → number of matching lines across FILES
  grep -rhnE "$1" $FILES 2>/dev/null | wc -l | tr -d ' '
}

note() {    # note <count> <label>
  [ "${1:-0}" -gt 0 ] 2>/dev/null || return 0
  hits=$((hits + $1))
  [ -n "$top" ] || top="$2"
}

# 1. Success announced next to a call that is not awaited.
#    Looks for a success notification whose preceding line calls something plainly.
n=$(grep -rn -B1 -E 'toast\.success|setSuccess\(true\)|showSuccess|alert\("[^"]*(saved|success|deleted|sent)' $FILES 2>/dev/null \
    | grep -E '^[^:]+-[0-9]+-' | grep -E '[a-zA-Z_$][A-Za-z0-9_.$]*\(' | grep -vc 'await\|\.then(' )
note "${n:-0}" "success reported before await"

# 2. catch/except that produces a success value.
n=$(grep -rn -A3 -E 'catch\s*[({]|except[ :]' $FILES 2>/dev/null \
    | grep -cE 'success["'\'']?\s*[:=]\s*[Tt]rue|return\s+True|"status"\s*:\s*"(ok|sent|success)"')
note "${n:-0}" "catch block returning success"

# 3. Controls wired to nothing.
n=$(count 'onClick=\{\s*\(\)\s*=>\s*\{\s*\}\s*\}|href="#"|@click="\s*"')
note "${n:-0}" "handler that does nothing"

# 4. localhost or a literal credential in shipped source.
n=$(count 'https?://localhost|https?://127\.0\.0\.1|sk_live_[A-Za-z0-9]|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}')
note "${n:-0}" "localhost or credential literal"

# 5. fetch result consumed without any status check in the same files.
used=$(count 'await\s+fetch\(')
checked=$(count 'res(ponse)?\.ok|\.status\s*[=!]==?\s*[0-9]|validateStatus')
if [ "${used:-0}" -gt "${checked:-0}" ]; then
  note "$((used - checked))" "fetch result used without checking status"
fi

# ── Memory ───────────────────────────────────────────────────────────────────
# The tripwire remembers its last count so it can tell you when something you were
# warned about is gone. That closing note is the moment the tool proves its worth —
# without it you only ever hear complaints.
#
# It reports a FACT ("no longer present"), never credit ("fixed thanks to us").
# VibeProof did not write the fix; claiming it would be exactly the kind of small
# lie this tool exists to find.
# State lives OUTSIDE the audited repository, keyed by its root path.
# Writing counters into someone's working tree would show up in git status and,
# eventually, in a commit. A tool whose first rule is "never modify your code"
# should not leave litter behind either.
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
