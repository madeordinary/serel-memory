#!/usr/bin/env bash
# Guards the v0.x compatibility contract for the Basecamp -> Serel Memory rename.
set -euo pipefail

fail=0
canonical="madeordinary/serel-memory"
legacy="gusfeliciano/basecamp"
claude_sync=".claude/commands/sync-upstream.md"
codex_sync=".agents/skills/sync-upstream/SKILL.md"

for file in README.md "$claude_sync" "$codex_sync"; do
  if ! grep -Fq "$canonical" "$file"; then
    echo "MISSING: canonical upstream $canonical in $file"
    fail=1
  fi
done

for file in "$claude_sync" "$codex_sync"; do
  if ! grep -Fq 'name remains the single provenance-anchor' "$file" || \
     ! grep -Fq 'filename for every v0.x release.' "$file"; then
    echo "MISSING: v0.x .basecamp.json compatibility promise in $file"
    fail=1
  fi
  if ! grep -Fq "$legacy" "$file"; then
    echo "MISSING: legacy upstream compatibility in $file"
    fail=1
  fi
done

if grep -Eq 'npx degit gusfeliciano/basecamp|git clone .+github\.com/gusfeliciano/basecamp' README.md; then
  echo "STALE: README install instructions still use the legacy repository"
  fail=1
fi

guard="github.repository == 'madeordinary/serel-memory'"
guard_count="$(grep -Fc "$guard" .github/workflows/ci.yml)"
if [ "$guard_count" -ne 2 ]; then
  echo "BAD GUARD: expected the canonical repository guard on both CI jobs"
  fail=1
fi
if grep -Fq "github.repository == 'madeordinary/serel-memory' ||" .github/workflows/ci.yml; then
  echo "STALE GUARD: CI still carries the pre-transfer legacy repository condition"
  fail=1
fi

assert_disabled() {
  local hook="$1"
  local new_value="$2"
  local legacy_value="$3"
  local output

  output="$(env SEREL_MEMORY_HOOKS="$new_value" BASECAMP_HOOKS="$legacy_value" bash "$hook")"
  if [ -n "$output" ]; then
    echo "HOOK RAN: $hook with SEREL_MEMORY_HOOKS=$new_value BASECAMP_HOOKS=$legacy_value"
    fail=1
  fi
}

for hook in hooks/session-start.sh hooks/pre-compact.sh; do
  if [ -z "$(env -u SEREL_MEMORY_HOOKS -u BASECAMP_HOOKS bash "$hook")" ]; then
    echo "BAD FIXTURE: $hook produced no baseline output"
    fail=1
  fi

  assert_disabled "$hook" off ""
  assert_disabled "$hook" "" off
  assert_disabled "$hook" off on
  assert_disabled "$hook" on off
done

if [ "$fail" -eq 0 ]; then
  echo "rename compatibility OK: canonical upstream plus v0.x legacy anchors and hook controls"
fi
exit "$fail"
