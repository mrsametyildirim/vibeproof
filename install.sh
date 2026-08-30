#!/usr/bin/env sh
# VibeProof installer — copies the skill into every agent directory it finds.
# No dependencies, no network, no build. POSIX sh on purpose.

set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/skills/vibeproof"
WITH_HOOK=0
[ "${1:-}" = "--with-hook" ] && WITH_HOOK=1

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "error: skills/vibeproof/SKILL.md not found next to this script." >&2
  echo "       run ./install.sh from inside the cloned repository." >&2
  exit 1
fi

# Agent skill directories, in the order we look for them.
TARGETS="$HOME/.claude/skills $HOME/.cursor/skills $HOME/.codex/skills"

installed=0
for dir in $TARGETS; do
  parent="$(dirname "$dir")"
  # Only install where the agent is actually set up, so we don't scatter
  # directories into the home folder of someone who uses one tool.
  [ -d "$parent" ] || continue

  mkdir -p "$dir"
  rm -rf "$dir/vibeproof"
  cp -R "$SRC" "$dir/vibeproof"
  echo "  installed  $dir/vibeproof"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ]; then
  echo "No agent directory found (~/.claude, ~/.cursor, ~/.codex)."
  echo
  echo "Copy it manually to wherever your agent reads skills from:"
  echo "  cp -r skills/vibeproof <your-agent-skills-dir>/"
  exit 1
fi

echo
echo "VibeProof installed. Open a project and run:"
echo
echo "  /vibeproof"
echo

# ── Optional tripwire ────────────────────────────────────────────────────────
# Deliberately opt-in. Editing someone's settings.json without asking is exactly
# the kind of thing this tool exists to complain about.
mkdir -p "$HOME/.vibeproof"
cp "$ROOT/hooks/tripwire.sh" "$HOME/.vibeproof/tripwire.sh"
chmod +x "$HOME/.vibeproof/tripwire.sh" 2>/dev/null || true

# The path is expanded here on purpose. A snippet containing $HOME looks portable
# but is silently dead on Windows: the hook runner does not expand it, sh receives
# a literal '$HOME', fails to find the file, and exits 0 — so the hook appears
# installed and never runs. Resolving it here avoids that entirely.
HOME_FWD=$(printf '%s' "$HOME" | tr '\\' '/')
HOOK_CMD="sh \"$HOME_FWD/.vibeproof/tripwire.sh\""
SETTINGS="$HOME/.claude/settings.json"

register_hook() {
  command -v python >/dev/null 2>&1 && PY=python || PY=python3
  command -v "$PY" >/dev/null 2>&1 || { echo "  python not found — add the snippet manually."; return 1; }
  VP_SETTINGS="$SETTINGS" VP_CMD="$HOOK_CMD" "$PY" - <<'PY'
import json, os, shutil, sys, time
p, cmd = os.environ["VP_SETTINGS"], os.environ["VP_CMD"]
d = {}
if os.path.exists(p):
    shutil.copy2(p, p + ".bak-" + time.strftime("%Y%m%d-%H%M"))
    try:
        d = json.load(open(p, encoding="utf-8"))
    except ValueError:
        print("  settings.json is not valid JSON — not touching it."); sys.exit(1)
stop = d.setdefault("hooks", {}).setdefault("Stop", [])
if any("tripwire" in json.dumps(g) for g in stop):
    print("  already registered."); sys.exit(0)
# Append. Never replace: an existing Stop hook is someone else's working setup.
stop.append({"hooks": [{"type": "command", "command": cmd}]})
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("  hook registered in ~/.claude/settings.json (previous file backed up).")
PY
}

if [ "$WITH_HOOK" -eq 1 ]; then
  echo "Registering the tripwire…"
  register_hook
  echo
  echo "It stays silent unless something trips, and never modifies your code."
else
  cat <<SNIP
Optional — get a nudge when the agent writes something suspicious:

  ./install.sh --with-hook

or add this to ~/.claude/settings.json yourself, alongside any existing Stop hook:

  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command",
      "command": "$HOOK_CMD" }] }]
  }

It stays silent unless something trips, and never modifies your code.
SNIP
fi
