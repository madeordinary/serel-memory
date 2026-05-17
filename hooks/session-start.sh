#!/usr/bin/env bash
# basecamp SessionStart hook
#
# Auto-loads the memory bank as session context so you don't need to type /start.
# Registered via hooks/enable-hooks.sh. Off by default.
#
# To disable temporarily for one session: export BASECAMP_HOOKS=off
# To disable permanently: remove the entries from .claude/settings.json

set -euo pipefail

# Honor the kill-switch
if [ "${BASECAMP_HOOKS:-}" = "off" ]; then
  exit 0
fi

# Anchor to the project root (where this hook was registered)
# Claude Code runs hooks from the project root, but be defensive.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Bail quietly if there's no memory bank — basecamp isn't installed here
if [ ! -d "$ROOT/memory-bank" ]; then
  exit 0
fi

cat <<'HEADER'
## Project context (auto-loaded by basecamp)

You are starting a session on a project using the basecamp memory bank pattern.
The contents below were read automatically at session start. Treat the memory
bank as the source of truth for project intent. If it conflicts with the actual
code, the code is correct and the bank needs updating — flag this to the user.

HEADER

for f in projectbrief productContext systemPatterns techContext activeContext progress; do
  file="$ROOT/memory-bank/$f.md"
  if [ -f "$file" ]; then
    echo "### memory-bank/$f.md"
    echo ""
    cat "$file"
    echo ""
    echo ""
  fi
done

if [ -f "$ROOT/.rules" ]; then
  echo "### .rules"
  echo ""
  cat "$ROOT/.rules"
  echo ""
fi

# Recent git activity, best-effort
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "### Recent activity"
  echo ""
  echo "Last 10 commits:"
  git -C "$ROOT" log --oneline -10 2>/dev/null || true
  echo ""
  echo "Working tree:"
  status=$(git -C "$ROOT" status --short 2>/dev/null | head -20)
  if [ -n "$status" ]; then
    echo "$status"
  else
    echo "(clean)"
  fi
  echo ""
fi

echo "---"
echo ""
echo "End of auto-loaded context. Continue with the user's request."
