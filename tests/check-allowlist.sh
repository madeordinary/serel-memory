#!/usr/bin/env bash
# Asserts the sync-upstream framework allowlist NEVER includes a user-memory path.
# memory-bank/ and .rules are the user's project content; if either ever lands in
# the allowlist, `git restore --source=upstream` could clobber a downstream user's
# memory on sync. This invariant must hold in both adapters.
#
# We inspect the canonical allowlist line (the space-separated path list that the
# sync git commands consume), NOT a broad grep — the docs legitimately mention
# memory-bank/ as a "never sync" path, which a naive grep would false-positive on.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
for f in .claude/commands/sync-upstream.md .agents/skills/sync-upstream/SKILL.md; do
  # Every line that carries the allowlist signature (the fenced list and any git
  # command that inlines it). Anchored on the first two framework paths.
  # No `-n`: a line-number prefix would defeat the start-of-line `.rules` match.
  matches="$(grep -E '\.agents/skills/ \.claude/commands/' "$f" || true)"
  if [ -z "$matches" ]; then
    echo "ALLOWLIST NOT FOUND in $f"; fail=1; continue
  fi
  if echo "$matches" | grep -qE 'memory-bank|(^| )\.rules($| )'; then
    echo "FORBIDDEN: sync allowlist in $f includes a user-memory path:"
    echo "$matches" | grep -E 'memory-bank|\.rules' | sed 's/^/  /'
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "allowlist OK: no memory-bank/ or .rules in the sync scope of either adapter"
fi
exit "$fail"
