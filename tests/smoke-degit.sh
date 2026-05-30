#!/usr/bin/env bash
# Simulates what `npx degit gusfeliciano/basecamp` ships — the tracked file tree —
# using `git archive` (no network, no npx), then asserts the export is a CLEAN
# STARTER: the memory bank is template scaffolding, not basecamp's own live bank,
# and the gitignored maintainer bank never leaks.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git archive --format=tar HEAD | tar -x -C "$tmp"

fail=0

# 1. The maintainer's private bank must never ship.
if [ -e "$tmp/memory-bank.local" ]; then
  echo "LEAK: memory-bank.local/ is present in the degit export"; fail=1
fi

# 2. No basecamp-specific live dev content in the shipped bank or .rules.
if grep -rniE '17/17|skill parity|basecamp framework is at|cherry-pick by commit in sync' \
     "$tmp/memory-bank" "$tmp/.rules" 2>/dev/null; then
  echo "LEAK: live basecamp dev content found in the shipped memory bank/.rules"; fail=1
fi

# 3. The shipped bank must still be template scaffolding (comment guidance present).
for f in projectbrief productContext systemPatterns techContext activeContext progress decisionLog; do
  if ! grep -q '<!--' "$tmp/memory-bank/$f.md"; then
    echo "NOT A TEMPLATE: memory-bank/$f.md ships without comment scaffolding"; fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "degit smoke OK: export ships clean templates; no private bank leak"
fi
exit "$fail"
