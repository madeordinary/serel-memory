#!/usr/bin/env bash
# Asserts the sync-upstream framework allowlist NEVER includes a user-memory path
# or per-project state. memory-bank/ and .rules are the user's project content,
# and .serel-memory.json is the project's provenance anchor; if any of them ever
# lands in the allowlist, `git restore --source=upstream` could clobber a
# downstream user's memory or anchor on sync. This invariant must hold in both
# adapters.
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
  if echo "$matches" | grep -qE 'memory-bank|(^| )\.rules($| )|\.serel-memory\.json'; then
    echo "FORBIDDEN: sync allowlist in $f includes a user-memory or per-project path:"
    echo "$matches" | grep -E 'memory-bank|\.rules|\.serel-memory\.json' | sed 's/^/  /'
    fail=1
  fi
  # Positive coverage: every framework path must be IN the allowlist, or a
  # downstream sync silently stops updating it. bin/serel-memory is the newest
  # one — the drift checker ships with the framework, not with the project.
  # Checked per LINE, never aggregated: one complete list must not vouch for a
  # second line (or the other adapter) that dropped a path.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    for required in bin/serel-memory hooks/ AGENTS.md; do
      case "$line" in
        *"$required"*) ;;
        *) echo "MISSING: an allowlist line in $f does not include $required:"
           echo "  $line"
           fail=1 ;;
      esac
    done
  done <<<"$matches"
done

if [ "$fail" -eq 0 ]; then
  echo "allowlist OK: no memory-bank/, .rules, or .serel-memory.json in the sync scope of either adapter"
fi
exit "$fail"
