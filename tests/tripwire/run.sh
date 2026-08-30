#!/usr/bin/env sh
# Tripwire test harness — no bats, no python, no node, no npm install.
#
# Each case builds a throwaway git repository, writes files into it, runs the
# hook, and asserts on what it printed. That is the only thing a user ever sees,
# so it is the only thing worth asserting on.
#
# Run:  sh tests/tripwire/run.sh
# Exit: 0 all passed, 1 something failed

set -u

HOOK=$(cd "$(dirname "$0")/../.." && pwd)/hooks/tripwire.sh
[ -f "$HOOK" ] || { echo "hook not found: $HOOK"; exit 1; }

pass=0
fail=0
FAILED=""

# Each case gets its own repo AND its own state dir, so the "cleared" memory of
# one test cannot leak into the next.
new_repo() {
  REPO=$(mktemp -d)
  export VIBEPROOF_STATE="$REPO/.state"
  cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.t
  git config user.name t
  git commit -q --allow-empty -m init
}

run_hook() { sh "$HOOK" 2>&1; }

# ok <name> <expectation> <actual>
#   expectation: "contains:TEXT" | "empty" | "notcontains:TEXT"
ok() {
  name=$1; expect=$2; actual=$3
  case $expect in
    empty)
      if [ -z "$(printf '%s' "$actual" | tr -d '[:space:]')" ]; then
        pass=$((pass+1)); printf '  ok   %s\n' "$name"; return
      fi ;;
    contains:*)
      if printf '%s' "$actual" | grep -qF "${expect#contains:}"; then
        pass=$((pass+1)); printf '  ok   %s\n' "$name"; return
      fi ;;
    notcontains:*)
      if ! printf '%s' "$actual" | grep -qF "${expect#notcontains:}"; then
        pass=$((pass+1)); printf '  ok   %s\n' "$name"; return
      fi ;;
  esac
  fail=$((fail+1)); FAILED="$FAILED\n  - $name"
  printf '  FAIL %s\n       expected %s\n       got: %s\n' "$name" "$expect" "$(printf '%s' "$actual" | tr '\n' ' ')"
}

echo "tripwire tests"

# ── 1. Filename containing a space ───────────────────────────────────────────
# The v1 defect: the file list was passed unquoted to grep, so this file was
# split into two nonexistent paths and silently produced no match.
new_repo
mkdir -p src
printf '<button onClick={() => {}}>X</button>\n' > "src/a b.js"
ok "filename with a space is scanned" "contains:VibeProof" "$(run_hook)"

# ── 2. Filename with a tab and quotes ────────────────────────────────────────
new_repo
mkdir -p src
# The redirection itself can fail (Windows forbids tabs in filenames), and that
# error comes from the shell rather than a command — so it is wrapped in a
# subshell to keep the output clean when the platform says no.
if ( printf '<button onClick={() => {}}>X</button>
' > "src/we'''ird	name.js" ) 2>/dev/null; then
  ok "filename with tab and quote is scanned" "contains:VibeProof" "$(run_hook)"
else
  pass=$((pass+1)); printf '  ok   filename with tab and quote (skipped: filesystem forbids it)
'
fi

# ── 3. Single changed file still trips ───────────────────────────────────────
# grep omits the filename prefix when given exactly one file; the -H flag is what
# keeps check 1 working in the most common case there is.
new_repo
mkdir -p src
printf 'async function s(){\n  saveProfile(data);\n  toast.success("Saved");\n}\n' > src/one.js
ok "single changed file trips" "contains:before await" "$(run_hook)"

# ── 4. Untracked new file is seen ────────────────────────────────────────────
new_repo
mkdir -p src
printf '<button onClick={() => {}}>Go</button>\n' > src/fresh.jsx
ok "untracked file is scanned" "contains:VibeProof" "$(run_hook)"

# ── 5. Unchecked fetch trips ─────────────────────────────────────────────────
new_repo
mkdir -p src
printf 'async function s(){\n  const r = await fetch("/api/save");\n  return r;\n}\n' > src/f.js
ok "unchecked fetch trips" "contains:without checking status" "$(run_hook)"

# ── 6. Checked fetch in the same file is quiet ───────────────────────────────
new_repo
mkdir -p src
printf 'async function s(){\n  const r = await fetch("/api/save");\n  if (!r.ok) throw new Error("x");\n}\n' > src/f.js
ok "checked fetch is quiet" "empty" "$(run_hook)"

# ── 7. res.ok in an UNRELATED file must not mask it ──────────────────────────
# The v1 defect: totals were compared repository-wide, so this passed silently.
new_repo
mkdir -p src
printf 'async function s(){\n  const r = await fetch("/api/save");\n  toast.success("Saved");\n}\n' > src/save.js
printf 'export function other(res){\n  if (res.ok) return 1;\n  return 0;\n}\n' > src/unrelated.js
ok "unrelated res.ok does not mask an unchecked fetch" "contains:VibeProof" "$(run_hook)"

# ── 8. No-op button ──────────────────────────────────────────────────────────
new_repo
mkdir -p src
printf '<button onClick={() => {}}>Settings</button>\n' > src/b.jsx
ok "no-op button trips" "contains:handler that does nothing" "$(run_hook)"

# ── 9. catch returning success ───────────────────────────────────────────────
new_repo
mkdir -p src
printf 'try {\n  await save();\n} catch (e) {\n  return { success: true };\n}\n' > src/c.js
ok "catch returning success trips" "contains:catch block returning success" "$(run_hook)"

# ── 10. Credential outranks a no-op button in the same file ──────────────────
# The v1 defect: "strongest signal" kept whichever matched FIRST, so the dead
# button won and the live key was never named.
new_repo
mkdir -p src
printf '<button onClick={() => {}}>X</button>\nconst k = "sk_live_ABCDEF123456";\n' > src/mix.jsx
ok "credential outranks no-op button" "contains:credential literal" "$(run_hook)"

# ── 11. Destructive dead control outranks a plain one ────────────────────────
new_repo
mkdir -p src
printf '<button onClick={() => {}}>Collapse</button>\n<button onClick={() => {}}>Delete account</button>\n' > src/d.jsx
ok "destructive dead control is named" "contains:destructive" "$(run_hook)"

# ── 12. Deleted route produces an advisory ───────────────────────────────────
new_repo
mkdir -p app/checkout
printf 'export default function P(){ return null; }\n' > app/checkout/page.tsx
git add -A && git commit -q -m add
rm app/checkout/page.tsx
ok "deleted route is reported" "contains:removed" "$(run_hook)"

# ── 13. Deletion is not called a bug ─────────────────────────────────────────
ok "deletion is not called suspicious" "notcontains:suspicious pattern" "$(cd "$REPO" && run_hook)"

# ── 14. Test fixtures are ignored ────────────────────────────────────────────
new_repo
mkdir -p src/__tests__
printf '<button onClick={() => {}}>X</button>\n' > src/__tests__/a.test.jsx
ok "test fixtures are ignored" "empty" "$(run_hook)"

# ── 15. Clean code prints nothing ────────────────────────────────────────────
new_repo
mkdir -p src
printf 'export function add(a, b) {\n  return a + b;\n}\n' > src/clean.js
ok "clean code is silent" "empty" "$(run_hook)"

# ── 16. Cleared warning is reported once, then stays quiet ───────────────────
new_repo
mkdir -p src
printf '<button onClick={() => {}}>X</button>\n' > src/x.jsx
run_hook >/dev/null 2>&1                       # trip it
printf 'export const x = 1;\n' > src/x.jsx     # fix it
ok "cleared warning is announced" "contains:no longer present" "$(run_hook)"
ok "second run after clearing is silent" "empty" "$(run_hook)"

# ── 17. Repeated run on clean repo stays silent ──────────────────────────────
ok "third run stays silent" "empty" "$(run_hook)"

# ── 18. Unicode path ─────────────────────────────────────────────────────────
new_repo
mkdir -p src
if ( printf '<button onClick={() => {}}>X</button>
' > "src/ürün-sayfası.jsx" ) 2>/dev/null; then
  ok "unicode filename is scanned" "contains:VibeProof" "$(run_hook)"
else
  pass=$((pass+1)); printf '  ok   unicode filename (skipped: filesystem)
'
fi

# ── 19. .mjs / .cts are covered ──────────────────────────────────────────────
new_repo
mkdir -p src
printf 'async function s(){\n  const r = await fetch("/api/x");\n  return r;\n}\n' > src/a.mjs
ok ".mjs is scanned" "contains:VibeProof" "$(run_hook)"

new_repo
mkdir -p src
printf 'async function s(){\n  const r = await fetch("/api/x");\n  return r;\n}\n' > src/a.cts
ok ".cts is scanned" "contains:VibeProof" "$(run_hook)"

# ── 20. Ant Design / notistack success mechanisms ────────────────────────────
new_repo
mkdir -p src
printf 'async function s(){\n  saveIt(data);\n  message.success("Saved");\n}\n' > src/antd.js
ok "message.success is recognised" "contains:before await" "$(run_hook)"

# ── 21. Correct synchronous setter before a toast is NOT flagged ─────────────
# The control case. A real fix in v1 came from this exact pattern being wrong.
new_repo
mkdir -p src
printf 'function onDeleted(fresh){\n  setNotes(fresh);\n  toast.success("Deleted");\n}\n' > src/ok.jsx
ok "synchronous setter before toast is not flagged" "empty" "$(run_hook)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then printf 'failed:%b\n' "$FAILED"; exit 1; fi
exit 0
