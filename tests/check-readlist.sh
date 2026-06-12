#!/usr/bin/env bash
# Guards the session-start read list against silent drift. The canonical
# 7-file memory bank list is duplicated by design in AGENTS.md, /start,
# $start, and hooks/session-start.sh — if a bank file is ever added or
# renamed in one place but not the others, agents and hook users silently
# read different banks. This test asserts all four artifacts agree.
set -euo pipefail
cd "$(dirname "$0")/.."

CANONICAL="projectbrief productContext systemPatterns techContext decisionLog activeContext progress"

fail=0

# 1. The hook's for-loop must match the canonical list exactly (incl. order).
hook_list="$(sed -n 's/^for f in \(.*\); do$/\1/p' hooks/session-start.sh)"
if [ "$hook_list" != "$CANONICAL" ]; then
  echo "DRIFT: hooks/session-start.sh for-loop is '$hook_list', expected '$CANONICAL'"
  fail=1
fi

# 2. AGENTS.md's startup read list must name the same 7 files in the same
# order (first 7 memory-bank/<name>.md references in the file).
agents_list="$(grep -o 'memory-bank/[a-zA-Z]*\.md' AGENTS.md | head -7 | sed 's#memory-bank/##; s#\.md##' | tr '\n' ' ' | sed 's/ $//')"
if [ "$agents_list" != "$CANONICAL" ]; then
  echo "DRIFT: AGENTS.md read list is '$agents_list', expected '$CANONICAL'"
  fail=1
fi

# 3. Both start adapters must mention every canonical file.
for adapter in .claude/commands/start.md .agents/skills/start/SKILL.md; do
  for name in $CANONICAL; do
    if ! grep -q "$name\.md" "$adapter"; then
      echo "DRIFT: $adapter does not mention $name.md"
      fail=1
    fi
  done
done

if [ "$fail" -eq 0 ]; then
  echo "readlist OK: AGENTS.md, /start, \$start, and session-start.sh agree on the 7-file bank"
fi
exit "$fail"
