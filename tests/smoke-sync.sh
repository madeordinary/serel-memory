#!/usr/bin/env bash
# End-to-end smoke test of the /sync-upstream TEMPLATE-MODE procedure.
#
# Scaffolds a downstream project the way degit does (git archive, no shared
# history), creates a synthetic upstream delta (framework file changed, new
# framework file added, NON-framework template changed), then mechanically
# applies the procedure documented in .claude/commands/sync-upstream.md:
# anchor-based discovery, per-file restore, anchor advance.
#
# NOTE: this exercises the documented procedure, not live agent behavior —
# an agent could still misread the doc, but the doc's steps are proven to
# work and to protect user memory.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

GIT="git -c user.email=test@test -c user.name=smoke-sync"

# The allowlist the procedure operates on — parsed from the command doc so
# this test fails if the doc and the test ever disagree.
ALLOWLIST_LINE="$(grep -m1 '^\.agents/skills/ ' .claude/commands/sync-upstream.md)"
if [ -z "$ALLOWLIST_LINE" ]; then
  echo "FAIL: could not parse the framework allowlist from sync-upstream.md"
  exit 1
fi
read -r -a ALLOWLIST <<<"$ALLOWLIST_LINE"

# --- Build the "upstream" repo: a clone of this repo at HEAD ---------------
git clone --quiet "$ROOT" "$tmp/upstream"
# CI checkouts are detached HEADs, so the clone may lack a main branch — the
# sync procedure fetches upstream main, so pin one at HEAD.
git -C "$tmp/upstream" checkout --quiet -B main
ANCHOR_REF="$(git -C "$tmp/upstream" rev-parse HEAD)"

# --- Scaffold the downstream project (degit-style: tracked tree, no history)
mkdir "$tmp/project"
git archive --format=tar HEAD | tar -x -C "$tmp/project"
cd "$tmp/project"
$GIT init --quiet
$GIT add -A
$GIT commit --quiet -m "scaffold from basecamp"

# Install-time anchor (per README: written at install, points at the
# upstream version the project was scaffolded from).
printf '{ "upstream": "local/basecamp", "ref": "%s", "linked": false }\n' "$ANCHOR_REF" > .basecamp.json

# The user makes the project their own: real bank content, a .rules learning,
# and a custom command of their own.
echo "## Current focus: shipping the downstream widget" >> memory-bank/activeContext.md
echo "- USER LEARNING: keep this line" >> .rules
echo "# /custom — downstream-only command" > .claude/commands/custom.md
$GIT add -A
$GIT commit --quiet -m "user content"

# --- Synthetic upstream delta ----------------------------------------------
(
  cd "$tmp/upstream"
  echo "UPSTREAM-CHANGE-MARKER" >> .claude/commands/ship.md
  echo "# /new-workflow — added upstream" > .claude/commands/new-workflow.md
  echo "<!-- upstream template tweak — must NOT reach downstream via sync -->" >> memory-bank/activeContext.md
  $GIT add -A
  $GIT commit --quiet -m "upstream framework update + template tweak"
)

# --- Run the documented template-mode sync ---------------------------------
$GIT remote add upstream "$tmp/upstream"
$GIT fetch --quiet upstream main

# Step 4: no merge base => template mode (degit installs have no shared history).
if $GIT merge-base HEAD upstream/main >/dev/null 2>&1; then
  echo "FAIL: expected template mode (no merge base) for a degit-style install"
  exit 1
fi

# Step 5: anchor ref must resolve in the fetched upstream history, giving the
# precise "changed since last sync" report, limited to the allowlist.
if ! $GIT rev-parse --verify --quiet "$ANCHOR_REF^{commit}" >/dev/null; then
  echo "FAIL: anchor ref does not resolve after fetch"
  exit 1
fi
changed="$($GIT diff --name-only "$ANCHOR_REF" upstream/main -- "${ALLOWLIST[@]}")"

# Step 9: restore INDIVIDUAL files from the changed list — never directories.
while IFS= read -r f; do
  [ -n "$f" ] && $GIT restore --source=upstream/main -- "$f"
done <<<"$changed"

# Step 10: advance the anchor to the synced upstream commit.
printf '{ "upstream": "local/basecamp", "ref": "%s", "linked": false }\n' "$($GIT rev-parse upstream/main)" > .basecamp.json

# --- Assertions -------------------------------------------------------------
fail=0

echo "$changed" | grep -qx '.claude/commands/ship.md' \
  || { echo "FAIL: changed-file report missed .claude/commands/ship.md"; fail=1; }
echo "$changed" | grep -qx '.claude/commands/new-workflow.md' \
  || { echo "FAIL: changed-file report missed the new upstream file"; fail=1; }
echo "$changed" | grep -q '^memory-bank/' \
  && { echo "FAIL: allowlist leak — memory-bank/ showed up in the sync report"; fail=1; }

grep -q "UPSTREAM-CHANGE-MARKER" .claude/commands/ship.md \
  || { echo "FAIL: framework file was not updated from upstream"; fail=1; }
[ -f .claude/commands/new-workflow.md ] \
  || { echo "FAIL: new upstream framework file was not pulled"; fail=1; }

grep -q "shipping the downstream widget" memory-bank/activeContext.md \
  || { echo "FAIL: user memory bank content was lost"; fail=1; }
grep -q "upstream template tweak" memory-bank/activeContext.md \
  && { echo "FAIL: upstream template change clobbered the user's bank"; fail=1; }
grep -q "USER LEARNING: keep this line" .rules \
  || { echo "FAIL: user .rules content was lost"; fail=1; }
[ -f .claude/commands/custom.md ] \
  || { echo "FAIL: downstream custom command was deleted (directory restore?)"; fail=1; }

grep -q "$($GIT rev-parse upstream/main)" .basecamp.json \
  || { echo "FAIL: anchor was not advanced to the synced upstream commit"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "sync smoke OK: template-mode sync updates framework files, spares user memory, advances the anchor"
fi
exit "$fail"
