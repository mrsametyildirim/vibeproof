#!/usr/bin/env sh
# VibeProof installer — copies the skill into every agent directory it finds.
# No dependencies, no network, no build. POSIX sh on purpose.

set -eu

SRC="$(cd "$(dirname "$0")" && pwd)/skills/vibeproof"

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
