#!/bin/bash
# Dynamically symlinks every .agents/skills/<name>/ directory into
# .claude/skills/<name> so newly added skills are picked up at session start.
#
# Triggered by Claude Code's SessionStart hook (see .claude/settings.json).
# Idempotent: existing links/dirs are skipped.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SRC="${PROJECT_DIR}/.agents/skills"
DEST="${PROJECT_DIR}/.claude/skills"

# Nothing to sync if no upstream skills directory exists.
if [ ! -d "$SRC" ]; then
  exit 0
fi

mkdir -p "$DEST"

linked=0
for skill_dir in "$SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target="$DEST/$skill_name"
  if [ ! -L "$target" ] && [ ! -d "$target" ]; then
    ln -s "$skill_dir" "$target"
    linked=$((linked + 1))
  fi
done

# Quiet on no-op runs; only log when we actually changed something.
if [ "$linked" -gt 0 ]; then
  echo "session-start: symlinked $linked new skill(s) into .claude/skills/" >&2
fi
