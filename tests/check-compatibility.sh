#!/usr/bin/env bash
# v0.3.0 identifier guard for the Basecamp -> Serel Memory cutover.
#
# The v0.x compatibility contract ended at 0.3.0. This guard asserts:
#   1. No retired identifier — BASECAMP_HOOKS, .basecamp.json, or
#      gusfeliciano/basecamp — appears on any shipped live surface.
#      Historical exceptions (migration history stays truthful, plan §1.5):
#        - CHANGELOG.md
#        - docs/research/
#      Test-code exceptions (this guard's own patterns; migration fixtures):
#        - tests/check-compatibility.sh
#        - tests/smoke-migrate-v02-v03.sh
#      Adapter exception: the two sync-upstream adapters may name the legacy
#      anchor ONLY on lines that also say "legacy" (the fail-fast instruction).
#   2. Both sync-upstream adapters carry the legacy-anchor fail-fast guard,
#      byte-identical (parity of behavior, not just prose).
#   3. Canonical upstream references and the CI repo guard stay intact.
#   4. Hooks honor SEREL_MEMORY_HOOKS=off and no longer honor the retired
#      spelling.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
canonical="madeordinary/serel-memory"
claude_sync=".claude/commands/sync-upstream.md"
codex_sync=".agents/skills/sync-upstream/SKILL.md"

# --- 1. Retired-identifier scan over tracked live surfaces -------------------
scan_files="$(git ls-files | grep -vE \
  -e '^CHANGELOG\.md$' \
  -e '^docs/research/' \
  -e '^tests/check-compatibility\.sh$' \
  -e '^tests/smoke-migrate-v02-v03\.sh$' \
  -e '^\.claude/commands/sync-upstream\.md$' \
  -e '^\.agents/skills/sync-upstream/SKILL\.md$')"

if [ -z "$scan_files" ]; then
  echo "BAD FIXTURE: identifier scan found no files"
  fail=1
else
  hits="$(printf '%s\n' "$scan_files" | xargs grep -nE 'BASECAMP_HOOKS|\.basecamp\.json|gusfeliciano/basecamp' 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "RETIRED IDENTIFIER on a live surface (only CHANGELOG.md and docs/research/ may carry v0.x history):"
    printf '%s\n' "$hits" | sed 's/^/  /'
    fail=1
  fi
fi

# --- 2. Adapters: legacy anchor named only in the fail-fast context ----------
for f in "$claude_sync" "$codex_sync"; do
  if grep -qE 'BASECAMP_HOOKS|gusfeliciano/basecamp' "$f"; then
    echo "RETIRED IDENTIFIER in $f (old kill switch or old repository slug)"
    fail=1
  fi
  untagged="$(grep -F '.basecamp.json' "$f" | grep -vi 'legacy' || true)"
  if [ -n "$untagged" ]; then
    echo "UNTAGGED legacy-anchor mention in $f (every mention must be a legacy fail-fast line):"
    printf '%s\n' "$untagged" | sed 's/^/  /'
    fail=1
  fi
  if ! grep -qF 'Fail fast on a legacy-only anchor' "$f"; then
    echo "MISSING: legacy-anchor fail-fast instruction in $f"
    fail=1
  fi
done

guard_cmd="$(awk '/^[[:space:]]*# Legacy-anchor guard: fail fast/,/^[[:space:]]*fi[[:space:]]*$/' "$claude_sync")"
guard_skill="$(awk '/^[[:space:]]*# Legacy-anchor guard: fail fast/,/^[[:space:]]*fi[[:space:]]*$/' "$codex_sync")"
if [ -z "$guard_cmd" ] || [ -z "$guard_skill" ]; then
  echo "MISSING: legacy-anchor guard snippet in one or both adapters"
  fail=1
elif [ "$guard_cmd" != "$guard_skill" ]; then
  echo "DRIFT: legacy-anchor guard snippet differs between adapters"
  fail=1
fi

# --- 3. Canonical upstream + CI repository guard ------------------------------
for file in README.md "$claude_sync" "$codex_sync"; do
  if ! grep -Fq "$canonical" "$file"; then
    echo "MISSING: canonical upstream $canonical in $file"
    fail=1
  fi
done

guard="github.repository == 'madeordinary/serel-memory'"
guard_count="$(grep -Fc "$guard" .github/workflows/ci.yml)"
if [ "$guard_count" -ne 2 ]; then
  echo "BAD GUARD: expected the canonical repository guard on both CI jobs"
  fail=1
fi

# --- 4. Hook kill switch -------------------------------------------------------
for hook in hooks/session-start.sh hooks/pre-compact.sh; do
  # Baseline: the hook produces output when no kill switch is set.
  if [ -z "$(env -u SEREL_MEMORY_HOOKS bash "$hook")" ]; then
    echo "BAD FIXTURE: $hook produced no baseline output"
    fail=1
  fi
  # The kill switch silences it.
  if [ -n "$(env SEREL_MEMORY_HOOKS=off bash "$hook")" ]; then
    echo "HOOK RAN: $hook with SEREL_MEMORY_HOOKS=off"
    fail=1
  fi
  # The retired v0.x spelling must NOT disable it anymore (full cutover).
  if [ -z "$(env -u SEREL_MEMORY_HOOKS BASECAMP_HOOKS=off bash "$hook")" ]; then
    echo "LEGACY SPELLING HONORED: $hook stayed silent with the retired v0.x kill switch"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "identifier cutover OK: no retired v0.x identifiers on live surfaces; fail-fast guard in both adapters; hooks honor only SEREL_MEMORY_HOOKS"
fi
exit "$fail"
