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

# Documented snippets, extracted verbatim from BOTH adapters and required to
# agree — the test runs what the doc tells an agent to run.
extract() { awk "/^[[:space:]]*$2/,/^[[:space:]]*fi[[:space:]]*\$/" "$1"; }
UPDATE_SNIPPET="$(extract .claude/commands/sync-upstream.md '# Anchor update: keep every other key')"
[ -n "$UPDATE_SNIPPET" ] || { echo "FAIL: could not extract the anchor-update snippet from sync-upstream.md"; exit 1; }
[ "$UPDATE_SNIPPET" = "$(extract .agents/skills/sync-upstream/SKILL.md '# Anchor update: keep every other key')" ] \
  || { echo "FAIL: anchor-update snippet differs between command and skill adapters"; exit 1; }
# shellcheck disable=SC2016  # the \$ is a literal for grep, not an expansion
ROOT_SNIPPET="$(grep -m1 '^[[:space:]]*cd "\$(git rev-parse --show-toplevel)"' .claude/commands/sync-upstream.md | sed 's/^[[:space:]]*//')"
[ -n "$ROOT_SNIPPET" ] || { echo "FAIL: sync-upstream.md has no repo-root cd line"; exit 1; }
# shellcheck disable=SC2016
grep -q '^[[:space:]]*cd "\$(git rev-parse --show-toplevel)"' .agents/skills/sync-upstream/SKILL.md \
  || { echo "FAIL: sync-upstream skill has no repo-root cd line"; exit 1; }
# shellcheck disable=SC2016  # fixed-string search for a literal $( in the doc
create_start="$(grep -n -F 'UP="$(git remote get-url upstream' .claude/commands/sync-upstream.md | head -1 | cut -d: -f1)"
create_end="$(grep -n -F '"linked": true }' .claude/commands/sync-upstream.md | awk -F: -v s="$create_start" '$1 > s {print $1; exit}')"
CREATE_SNIPPET="$( [ -n "$create_start" ] && [ -n "$create_end" ] && sed -n "${create_start},${create_end}p" .claude/commands/sync-upstream.md | sed 's/^[[:space:]]*//')"
RESOLVE_SNIPPET="$(awk '/^[[:space:]]*# Anchor resolve:/,/anchor does not resolve"$/' .claude/commands/sync-upstream.md | sed 's/^[[:space:]]*//')"
[ -n "$RESOLVE_SNIPPET" ] || { echo "FAIL: could not extract the anchor-resolve snippet from sync-upstream.md"; exit 1; }
[ "$RESOLVE_SNIPPET" = "$(awk '/^[[:space:]]*# Anchor resolve:/,/anchor does not resolve"$/' .agents/skills/sync-upstream/SKILL.md | sed 's/^[[:space:]]*//')" ] \
  || { echo "FAIL: anchor-resolve snippet differs between command and skill adapters"; exit 1; }
[ -n "$CREATE_SNIPPET" ] || { echo "FAIL: could not extract the anchor-create snippet from sync-upstream.md"; exit 1; }

# --- Build the "upstream" repo: a clone of this repo at HEAD ---------------
git clone --quiet "$ROOT" "$tmp/upstream"
# CI checkouts are detached HEADs, so the clone may lack a main branch — the
# sync procedure fetches upstream main, so pin one at HEAD.
git -C "$tmp/upstream" checkout --quiet -B main
# The install anchor is a TAG, as the README tells users to write it. Tags are
# not fetched by `git fetch upstream main`, which is exactly the bug the
# documented resolve step exists for.
git -C "$tmp/upstream" tag v9.9.9-fixture
ANCHOR_REF="v9.9.9-fixture"
ANCHOR_SHA="$(git -C "$tmp/upstream" rev-parse HEAD)"

# --- Scaffold the downstream project (degit-style: tracked tree, no history)
mkdir "$tmp/project"
git archive --format=tar HEAD | tar -x -C "$tmp/project"
cd "$tmp/project"
$GIT init --quiet
$GIT add -A
$GIT commit --quiet -m "scaffold from Serel Memory"

# Install-time anchor (per README: written at install, points at the
# upstream version the project was scaffolded from).
# The anchor carries extra keys — scoped banks plus a nested key that happens to
# be named "ref" — which a blind rewrite would destroy.
printf '{ "upstream": "local/serel-memory", "ref": "%s", "linked": true,\n  "scopes": ["projects"], "nested": { "ref": "keep-me" } }\n' "$ANCHOR_REF" > .serel-memory.json
mkdir -p projects/widget

# The user makes the project their own: real bank content, a .rules learning,
# and a custom command of their own.
echo "## Current focus: shipping the downstream widget" >> memory-bank/activeContext.md
echo "- USER LEARNING: keep this line" >> .rules
echo "# /custom — downstream-only command" > .claude/commands/custom.md
# ... and deletes an allowlisted framework doc that will NOT change upstream.
git rm -q docs/cross-agent-review.md
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

# Step 3: the tag anchor must NOT resolve from `fetch upstream main` alone
# (that is the bug), and MUST resolve through the documented resolve snippet,
# into a private ref that leaves the project's own tags untouched.
$GIT rev-parse --verify --quiet "$ANCHOR_REF^{commit}" >/dev/null \
  && { echo "FAIL: fixture invalid — tag anchor resolved before the resolve step"; exit 1; }
resolve_out="$(bash -c "$RESOLVE_SNIPPET" 2>&1)"
printf '%s\n' "$resolve_out" | grep -q '^anchor resolves: refs/serel-memory/anchor$' \
  || { echo "FAIL: documented resolve step did not resolve the tag anchor: $resolve_out"; exit 1; }
[ "$($GIT rev-parse "refs/serel-memory/anchor^{commit}")" = "$ANCHOR_SHA" ] \
  || { echo "FAIL: private anchor ref points at the wrong commit"; exit 1; }
$GIT tag -l | grep -qx "$ANCHOR_REF" && { echo "FAIL: resolve step polluted the project's tags"; exit 1; }
ANCHOR="refs/serel-memory/anchor"

# Step 5: precise report since the anchor, plus files the project no longer has.
changed="$($GIT diff --name-only "$ANCHOR" upstream/main -- "${ALLOWLIST[@]}")"
absent="$($GIT diff --name-only --diff-filter=A HEAD upstream/main -- "${ALLOWLIST[@]}")"

# Step 9: restore INDIVIDUAL files from both lists — never directories.
while IFS= read -r f; do
  [ -n "$f" ] && $GIT restore --source=upstream/main -- "$f"
done <<<"$(printf '%s\n%s\n' "$changed" "$absent" | sort -u)"

# Step 10: advance the anchor with the DOCUMENTED snippet (run from a scope
# folder on purpose: the documented root cd must bring it back to the root).
(cd projects/widget && bash -c "$ROOT_SNIPPET && $UPDATE_SNIPPET")

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
printf '%s\n' "$absent" | grep -qx 'docs/cross-agent-review.md' \
  || { echo "FAIL: allowlisted doc deleted downstream (unchanged upstream) was not offered back"; fail=1; }
[ -f docs/cross-agent-review.md ] \
  || { echo "FAIL: deleted framework doc was not restored"; fail=1; }
printf '%s\n' "$changed" | grep -qx 'docs/cross-agent-review.md' \
  && { echo "FAIL: unchanged doc showed up in the anchor diff (fixture invalid)"; fail=1; }

grep -q "shipping the downstream widget" memory-bank/activeContext.md \
  || { echo "FAIL: user memory bank content was lost"; fail=1; }
grep -q "upstream template tweak" memory-bank/activeContext.md \
  && { echo "FAIL: upstream template change clobbered the user's bank"; fail=1; }
grep -q "USER LEARNING: keep this line" .rules \
  || { echo "FAIL: user .rules content was lost"; fail=1; }
[ -f .claude/commands/custom.md ] \
  || { echo "FAIL: downstream custom command was deleted (directory restore?)"; fail=1; }

[ "$(jq -r .ref .serel-memory.json)" = "$($GIT rev-parse upstream/main)" ] \
  || { echo "FAIL: anchor was not advanced to the synced upstream commit"; fail=1; }
[ "$(jq -r .linked .serel-memory.json)" = "false" ] \
  || { echo "FAIL: anchor linked flag was not cleared after a reviewed sync"; fail=1; }
[ "$(jq -c .scopes .serel-memory.json)" = '["projects"]' ] \
  || { echo "FAIL: anchor update dropped the scopes key"; fail=1; }
[ "$(jq -r .nested.ref .serel-memory.json)" = "keep-me" ] \
  || { echo "FAIL: anchor update touched a nested key named ref"; fail=1; }
[ ! -e projects/widget/.serel-memory.json ] \
  || { echo "FAIL: sync run from a scope folder created a child anchor"; fail=1; }

# Step 5 "No anchor?": the documented reconstruction creates a linked anchor.
rm .serel-memory.json
(bash -c "$CREATE_SNIPPET")
[ "$(jq -r .linked .serel-memory.json)" = "true" ] \
  || { echo "FAIL: reconstructed anchor is not marked linked"; fail=1; }
[ "$(jq -r .ref .serel-memory.json)" = "$($GIT rev-parse upstream/main)" ] \
  || { echo "FAIL: reconstructed anchor does not point at upstream/main"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "sync smoke OK: template-mode sync updates framework files, spares user memory, advances the anchor"
fi
exit "$fail"
