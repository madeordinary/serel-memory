#!/usr/bin/env bash
# Serel Memory SessionStart hook
#
# Auto-loads the memory bank as session context so you don't need to type /start.
# Registered via hooks/enable-hooks.sh. Off by default.
#
# To disable temporarily for one session: export SEREL_MEMORY_HOOKS=off
# To disable permanently: remove the entries from .claude/settings.json

set -euo pipefail

# Honor the kill switch.
if [ "${SEREL_MEMORY_HOOKS:-}" = "off" ]; then
  exit 0
fi

# Anchor to the project root (where this hook was registered)
# Claude Code runs hooks from the project root, but be defensive.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Bail quietly if there's no memory bank — Serel Memory isn't installed here
if [ ! -d "$ROOT/memory-bank" ] && [ ! -d "$ROOT/memory-bank.local" ]; then
  exit 0
fi

# Maintainer overlay: upstream Serel Memory development keeps its real working
# bank in gitignored memory-bank.local/ (the tracked memory-bank/ ships as
# blank starter templates). When the overlay exists, it IS the effective bank.
# Downstream projects never have this directory.
BANK_DIR="$ROOT/memory-bank"
BANK_LABEL="memory-bank"
RULES_FILE="$ROOT/.rules"
RULES_LABEL=".rules"
if [ -d "$ROOT/memory-bank.local" ]; then
  BANK_DIR="$ROOT/memory-bank.local"
  BANK_LABEL="memory-bank.local"
  if [ -f "$ROOT/memory-bank.local/.rules" ]; then
    RULES_FILE="$ROOT/memory-bank.local/.rules"
    RULES_LABEL="memory-bank.local/.rules"
  fi
fi

cat <<'HEADER'
## Project context (auto-loaded by Serel Memory)

You are starting a session on a project using the Serel Memory bank pattern.
The contents below were read automatically at session start. Treat the memory
bank as the source of truth for project intent. If it conflicts with the actual
code, the code is correct and the bank needs updating — flag this to the user.

HEADER

for f in projectbrief productContext systemPatterns techContext decisionLog activeContext progress; do
  file="$BANK_DIR/$f.md"
  if [ -f "$file" ]; then
    echo "### $BANK_LABEL/$f.md"
    echo ""
    cat "$file"
    echo ""
    echo ""
  fi
done

if [ -f "$RULES_FILE" ]; then
  echo "### $RULES_LABEL"
  echo ""
  cat "$RULES_FILE"
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
