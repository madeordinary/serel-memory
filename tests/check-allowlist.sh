#!/usr/bin/env bash
# Asserts the sync-upstream framework allowlist NEVER includes a user-memory path
# or per-project state. memory-bank/ and .rules are the user's project content,
# and .serel-memory.json is the project's provenance anchor; if any of them ever
# lands in the allowlist, `git restore --source=upstream` could clobber a
# downstream user's memory or anchor on sync. This invariant must hold in the
# source and in its byte-identical Claude copy.
#
# We inspect the canonical allowlist line (the space-separated path list that the
# sync git commands consume), NOT a broad grep — the docs legitimately mention
# memory-bank/ as a "never sync" path, which a naive grep would false-positive on.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
source=.agents/skills/sync-upstream/SKILL.md
claude_copy=.claude/skills/sync-upstream/SKILL.md
if [ ! -f "$claude_copy" ] || ! cmp -s "$source" "$claude_copy"; then
  echo "DRIFT: $claude_copy is missing or differs from its source $source"
  fail=1
fi
for f in "$source" "$claude_copy"; do
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
  if echo "$matches" | grep -qF 'CLAUDE.md'; then
    echo "FORBIDDEN: sync allowlist in $f includes the retired CLAUDE.md shim"
    fail=1
  fi
  # Positive coverage: every framework path must be IN the allowlist, or a
  # downstream sync silently stops updating it. .claude/skills/ is the newest
  # one: Claude Code's copies of the workflows live there from 0.8.0, and
  # .claude/commands/ stays so sync can discover and retire 0.7.0-era commands.
  # Checked per LINE, never aggregated: one complete list must not vouch for a
  # second line (or the copy) that dropped a path.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    for required in .claude/skills/ .claude/commands/ bin/serel-memory hooks/ AGENTS.md docs/serel-setup.md; do
      case "$line" in
        *"$required"*) ;;
        *) echo "MISSING: an allowlist line in $f does not include $required:"
           echo "  $line"
           fail=1 ;;
      esac
    done
  done <<<"$matches"
done

# The drift checker's baseline and the local installer's payload are copies of
# the same list: a path added to one and not the others is either never
# compared or never installed.
canonical="$(grep -m1 '^\.agents/skills/ ' "$source" || true)"
expected=".agents/skills/ .claude/commands/ .claude/skills/ AGENTS.md docs/workflow-contract.md docs/cross-agent-review.md docs/serel-setup.md hooks/ bin/serel-memory"
if [ "$canonical" != "$expected" ]; then
  echo "DRIFT: the canonical allowlist in $source is '$canonical', expected '$expected'"
  fail=1
fi
for f in bin/serel-memory install.sh; do
  copy="$(awk '/^FRAMEWORK_PATHS=\(/,/\)$/' "$f" | tr -d '\\()' | sed 's/^FRAMEWORK_PATHS=//' | tr -s ' \n' '  ' | sed 's/^ //; s/ $//')"
  if [ -z "$canonical" ] || [ "$copy" != "$canonical" ]; then
    echo "DRIFT: FRAMEWORK_PATHS in $f is '$copy', expected the sync allowlist '$canonical'"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "allowlist OK: no memory-bank/, .rules, or .serel-memory.json in the sync scope; source, copy and both FRAMEWORK_PATHS agree"
fi
exit "$fail"
