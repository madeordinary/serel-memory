#!/usr/bin/env bash
# End-to-end smoke test of the v0.2 -> v0.3 downstream MIGRATION path.
#
# smoke-sync builds both sides from HEAD, so it can never catch a broken
# cross-version migration. This test fixtures a REAL old-vintage downstream
# repo — tooling from the local v0.2.0 tag plus a legacy .basecamp.json
# anchor — and drives it across the cutover with the documented pieces:
#
#   (a) FAIL FAST: the sync-upstream legacy-anchor guard (extracted verbatim
#       from .claude/commands/sync-upstream.md) must stop when only the
#       legacy anchor exists — no silent "unanchored", no baseline
#       reconstruction.
#   (b) MIGRATE + SYNC: after refreshing tooling per the per-file rule
#       (auto-replace only files byte-identical to a known upstream vintage)
#       and renaming the anchor to .serel-memory.json, the guard passes and
#       the documented template-mode sync runs to completion.
#
# Like smoke-sync, this exercises the documented procedure mechanically —
# it proves the doc's steps work, not that an agent can't misread them.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

GIT="git -c user.email=test@test -c user.name=smoke-migrate"

# The fixtures come from local release tags — no network.
for tag in v0.1.0 v0.2.0; do
  git rev-parse --verify --quiet "$tag^{commit}" >/dev/null \
    || { echo "FAIL: local tag $tag is required to build the migration fixture"; exit 1; }
done
V020_REF="$(git rev-parse "v0.2.0^{commit}")"

# The allowlist the procedure operates on — parsed from the command doc so
# this test fails if the doc and the test ever disagree.
ALLOWLIST_LINE="$(grep -m1 '^\.agents/skills/ ' .claude/commands/sync-upstream.md)"
if [ -z "$ALLOWLIST_LINE" ]; then
  echo "FAIL: could not parse the framework allowlist from sync-upstream.md"
  exit 1
fi
read -r -a ALLOWLIST <<<"$ALLOWLIST_LINE"

# The legacy-anchor guard, extracted verbatim from the command doc — the test
# runs what the doc tells an agent to run, not a paraphrase. (The snippet sits
# inside an indented list fence, so the patterns tolerate leading whitespace.)
GUARD_SNIPPET="$(awk '/^[[:space:]]*# Legacy-anchor guard: fail fast/,/^[[:space:]]*fi[[:space:]]*$/' .claude/commands/sync-upstream.md)"
if [ -z "$GUARD_SNIPPET" ]; then
  echo "FAIL: could not extract the legacy-anchor guard from sync-upstream.md"
  exit 1
fi
GUARD_SKILL="$(awk '/^[[:space:]]*# Legacy-anchor guard: fail fast/,/^[[:space:]]*fi[[:space:]]*$/' .agents/skills/sync-upstream/SKILL.md)"
if [ "$GUARD_SNIPPET" != "$GUARD_SKILL" ]; then
  echo "FAIL: legacy-anchor guard differs between command and skill adapters"
  exit 1
fi

# --- Source trees -------------------------------------------------------------
# The "upstream" repo: this repo at HEAD (the v0.3.0 candidate).
git clone --quiet "$ROOT" "$tmp/upstream"
# CI checkouts are detached HEADs, so the clone may lack a main branch — the
# sync procedure fetches upstream main, so pin one at HEAD.
git -C "$tmp/upstream" checkout --quiet -B main

# Known upstream vintages for the §1.3 per-file byte-identity rule.
mkdir "$tmp/vintage-v010" "$tmp/vintage-v020" "$tmp/v030"
git archive --format=tar v0.1.0 | tar -x -C "$tmp/vintage-v010"
git archive --format=tar v0.2.0 | tar -x -C "$tmp/vintage-v020"
git archive --format=tar HEAD | tar -x -C "$tmp/v030"

# --- Fixture: a downstream repo at v0.2.0 tooling vintage --------------------
mkdir "$tmp/project"
git archive --format=tar v0.2.0 | tar -x -C "$tmp/project"
cd "$tmp/project"
$GIT init --quiet
$GIT add -A
$GIT commit --quiet -m "scaffold from Serel Memory v0.2.0"

# Legacy install-time anchor, as a v0.x install would have written it.
printf '{ "upstream": "madeordinary/serel-memory", "ref": "%s", "linked": false }\n' "$V020_REF" > .basecamp.json

# The user makes the project their own: real bank content and a .rules learning.
echo "## Current focus: shipping the downstream widget" >> memory-bank/activeContext.md
echo "- USER LEARNING: keep this line" >> .rules
$GIT add -A
$GIT commit --quiet -m "v0.2.0 install + user content"

fail=0

# --- (a) Fail fast while only the legacy anchor exists -----------------------
if guard_out="$(bash -c "$GUARD_SNIPPET" 2>&1)"; then
  echo "FAIL: legacy-anchor guard did not stop with only .basecamp.json present"
  fail=1
else
  printf '%s\n' "$guard_out" | grep -q "MIGRATION REQUIRED" \
    || { echo "FAIL: guard stopped without the migrate-first message:"; printf '%s\n' "$guard_out" | sed 's/^/  /'; fail=1; }
fi
# Fail fast means fail CLEAN: no new anchor written, legacy anchor untouched.
[ -e .serel-memory.json ] \
  && { echo "FAIL: guard reconstructed a baseline anchor despite the legacy anchor"; fail=1; }
grep -q "$V020_REF" .basecamp.json \
  || { echo "FAIL: legacy anchor was modified during fail-fast"; fail=1; }

# --- Migrate: refresh tooling per the §1.3 per-file rule ---------------------
manual_merges=""
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -f "$rel" ]; then
    if cmp -s "$rel" "$tmp/v030/$rel"; then
      : # already current
    elif cmp -s "$rel" "$tmp/vintage-v020/$rel" || cmp -s "$rel" "$tmp/vintage-v010/$rel" 2>/dev/null; then
      cp "$tmp/v030/$rel" "$rel"
    else
      manual_merges="$manual_merges $rel"
    fi
  else
    mkdir -p "$(dirname "$rel")"
    cp "$tmp/v030/$rel" "$rel"
  fi
done <<EOF
$(find .claude/commands .agents/skills hooks -type f)
CLAUDE.md
EOF

if [ -n "$manual_merges" ]; then
  echo "FAIL: pristine v0.2.0 fixture should auto-replace cleanly; manual-merge needed:$manual_merges"
  fail=1
fi

# --- Anchor last: rename only after tooling verifies -------------------------
cmp -s hooks/session-start.sh "$tmp/v030/hooks/session-start.sh" \
  || { echo "FAIL: tooling refresh did not land the v0.3.0 hook"; fail=1; }
mv .basecamp.json .serel-memory.json
$GIT add -A
$GIT commit --quiet -m "migrate to Serel Memory v0.3.0 tooling"

# --- (b) Guard passes after the rename; sync runs to completion --------------
if ! guard_out="$(bash -c "$GUARD_SNIPPET" 2>&1)"; then
  echo "FAIL: legacy-anchor guard still stops after the anchor was renamed:"
  printf '%s\n' "$guard_out" | sed 's/^/  /'
  fail=1
fi

$GIT remote add upstream "$tmp/upstream"
$GIT fetch --quiet upstream main

# Step 4: no merge base => template mode (degit-style installs have no shared history).
if $GIT merge-base HEAD upstream/main >/dev/null 2>&1; then
  echo "FAIL: expected template mode (no merge base) for the migrated install"
  fail=1
fi

# Step 5: the migrated anchor's ref (the v0.2.0 commit) must resolve in the
# fetched upstream history, giving the precise changed-since-anchor report.
if ! $GIT rev-parse --verify --quiet "$V020_REF^{commit}" >/dev/null; then
  echo "FAIL: migrated anchor ref does not resolve after fetch"
  fail=1
fi
changed="$($GIT diff --name-only "$V020_REF" upstream/main -- "${ALLOWLIST[@]}")"

# The v0.2.0 -> v0.3.0 upstream delta must be reported ...
printf '%s\n' "$changed" | grep -qx '.claude/commands/sync-upstream.md' \
  || { echo "FAIL: changed report missed the cutover command adapter"; fail=1; }
printf '%s\n' "$changed" | grep -qx 'hooks/session-start.sh' \
  || { echo "FAIL: changed report missed the cutover hook change"; fail=1; }
printf '%s\n' "$changed" | grep -q '^memory-bank/' \
  && { echo "FAIL: allowlist leak — memory-bank/ showed up in the sync report"; fail=1; }

# ... and step 9's per-file restore is a no-op because the migration already
# landed those exact bytes (proves refresh and upstream agree).
while IFS= read -r f; do
  [ -n "$f" ] || continue
  cmp -s "$f" "$tmp/v030/$f" \
    || { echo "FAIL: refreshed tooling disagrees with upstream: $f"; fail=1; }
done <<<"$changed"

# Step 10 / migration finish: advance the anchor to the synced upstream commit.
printf '{ "upstream": "madeordinary/serel-memory", "ref": "%s", "linked": false }\n' "$($GIT rev-parse upstream/main)" > .serel-memory.json

# --- Final-state assertions ----------------------------------------------------
[ -e .basecamp.json ] \
  && { echo "FAIL: legacy anchor survived the migration"; fail=1; }
grep -q "$($GIT rev-parse upstream/main)" .serel-memory.json \
  || { echo "FAIL: anchor was not advanced to the synced upstream commit"; fail=1; }

cmd_count="$(find .claude/commands -name '*.md' | wc -l | tr -d ' ')"
skill_count="$(find .agents/skills -name SKILL.md | wc -l | tr -d ' ')"
[ "$cmd_count" -eq 17 ] || { echo "FAIL: expected 17 commands after migration, found $cmd_count"; fail=1; }
[ "$skill_count" -eq 17 ] || { echo "FAIL: expected 17 skills after migration, found $skill_count"; fail=1; }

grep -q "shipping the downstream widget" memory-bank/activeContext.md \
  || { echo "FAIL: user memory bank content was lost"; fail=1; }
grep -q "USER LEARNING: keep this line" .rules \
  || { echo "FAIL: user .rules content was lost"; fail=1; }

# The migrated hook honors the new kill switch — and only the new one.
grep -q 'BASECAMP_HOOKS' hooks/session-start.sh \
  && { echo "FAIL: migrated hook still reads the retired kill switch"; fail=1; }
[ -z "$(env SEREL_MEMORY_HOOKS=off bash hooks/session-start.sh)" ] \
  || { echo "FAIL: SEREL_MEMORY_HOOKS=off did not silence the migrated hook"; fail=1; }
[ -n "$(env -u SEREL_MEMORY_HOOKS bash hooks/session-start.sh)" ] \
  || { echo "FAIL: migrated hook produced no baseline output"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "migration smoke OK: legacy anchor fails fast; v0.2.0 fixture migrates to v0.3.0 and syncs clean"
fi
exit "$fail"
