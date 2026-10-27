#!/usr/bin/env bash
# Migration to the 0.8.0 layout (one source per workflow; Claude Code skills in
# .claude/skills/, no .claude/commands/), exercised the way users will run it.
#
# Starting points: degit-style scaffolds of v0.3.0, v0.6.0 and v0.7.0 (git
# archive, fresh history, anchored at the tag). Upstream: this tree in the
# 0.8.0 layout, as a bare repository whose history is this repository's. The
# layout is built mechanically (each .agents/skills/<n>/SKILL.md copied to
# .claude/skills/<n>/SKILL.md, ask-codex moved to a skill, commands dropped),
# so the suite holds before and after every workflow is converted.
#
# Routes:
#   - README update prompt: the fresh clone's sync body (its allowlist, guards
#     and the extracted retirement snippets) applied to the project.
#   - Installed Codex sync, two runs, from v0.6.0 and v0.7.0: run 1 follows the
#     project's own old .agents/skills/sync-upstream/SKILL.md, run 2 the body
#     run 1 installed.
#
# The simulated user pulls all safe changes, retires every matched command,
# keeps held workflows unless a case ports them, and commits after review.
#
# Cases:
#   1. Unmodified projects (all three tags, README route; v0.6.0 and v0.7.0
#      two-run route): every skill added, every inventory command retired
#      (worktree only, uncommitted), every framework file equal to upstream.
#   2. A customized ship command: held (its Claude skill, Codex skill and
#      retirement), the other workflows proceed; porting then retiring works,
#      and the recheck refuses changed or uncommitted bytes.
#   3. Separately customized Claude and Codex handoff adapters: held together;
#      ported per CLI, the copies stay different and the checker says so.
#   4. An anchor already advanced to 0.8.0 with commands left behind: the
#      checker reports them shadowed, and sync still offers the retirement.
#   5. Rename-shaped upstream history: discovery with --no-renames still sees
#      the deletion and the addition; the inventory finds it regardless.
#   6. A shallow clone, and no upstream/main: every command is held.
#   7. Always: a project-only .claude/commands/deploy.md (and its Codex
#      skill), a tracked Kit .claude/commands/polish.md (and its Codex skill)
#      and a local, ignored Kit .claude/skills/polish/ stay untouched, never
#      appear in discovery or the inventory, and give no drift findings; the
#      bank, .rules, CLAUDE.md and extra anchor keys stay unchanged.
#
# NOTE: this exercises the documented procedure, not live agent behavior.
# shellcheck disable=SC2015  # ok/bad never fail, so A && ok || bad is a plain either/or
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required for this test (and for sync)"; exit 1; }
for tag in v0.3.0 v0.6.0 v0.7.0; do
  git rev-parse --verify -q "refs/tags/$tag^{commit}" >/dev/null || {
    echo "FAIL: missing fixture tag $tag: run git fetch origin --tags (full history)"; exit 1; }
done

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
GIT="git -c user.email=test@test -c user.name=smoke-migrate -c commit.gpgsign=false"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
check() { # label command... -> ok when the command succeeds
  local label="$1"; shift
  if "$@"; then ok "$label"; else bad "$label"; fi
}

# --- Snippet extraction ------------------------------------------------------
# Old-style snippets end at their first bare `fi`; the retirement snippets end
# at their closing fence (they hold if/fi blocks of their own).
extract_fi() { awk "/^[[:space:]]*$2/,/^[[:space:]]*fi[[:space:]]*\$/" "$1"; }
extract_fence() { awk -v a="$2" 'index($0, a) { f = 1 } f && /^[[:space:]]*```/ { exit } f' "$1"; }

# load_doc <doc>: the allowlist and the snippets one sync body documents.
load_doc() {
  DOC="$1"
  local line
  line="$(grep -m1 '^\.agents/skills/ ' "$DOC")"
  read -r -a ALLOWLIST <<<"$line"
  RESOLVE="$(awk '/^[[:space:]]*# Anchor resolve:/,/anchor does not resolve"$/' "$DOC" | sed 's/^[[:space:]]*//')"
  UPDATE="$(extract_fi "$DOC" '# Anchor update: keep every other key')"
  LEGACY="$(extract_fi "$DOC" '# Legacy-anchor guard: fail fast')"
  LOCAL_GUARD="$(extract_fi "$DOC" '# Local-install guard:')"
  RESTORE_GUARD="$(extract_fi "$DOC" '# Restore guard:')"
  INVENTORY="$(extract_fence "$DOC" '# Retirement inventory:')"
  APPLY="$(extract_fence "$DOC" '# Retirement apply:')"
  if grep -q -- '--no-renames' "$DOC"; then RN=--no-renames; else RN=-M; fi
  [ "${#ALLOWLIST[@]}" -gt 0 ] && [ -n "$RESOLVE" ] && [ -n "$UPDATE" ] && [ -n "$LEGACY" ] ||
    { echo "FAIL: could not read the sync procedure from $DOC"; exit 1; }
}

# --- The 0.8.0 layout, mechanically ------------------------------------------
to_v08_layout() { # dir
  local d="$1" s n
  for s in "$d"/.agents/skills/*/SKILL.md; do
    n="$(basename "$(dirname "$s")")"
    [ "$n" = ask-claude ] && continue
    mkdir -p "$d/.claude/skills/$n"
    cp "$s" "$d/.claude/skills/$n/SKILL.md"
  done
  if [ -f "$d/.claude/commands/ask-codex.md" ] && [ ! -f "$d/.claude/skills/ask-codex/SKILL.md" ]; then
    mkdir -p "$d/.claude/skills/ask-codex"
    cp "$d/.claude/commands/ask-codex.md" "$d/.claude/skills/ask-codex/SKILL.md"
  fi
  rm -rf "$d/.claude/commands"
}

# --- Upstream: this working tree in the 0.8.0 layout, on this history -------
work="$tmp/upstream-work"
git clone --quiet "$ROOT" "$work"
git -C "$work" checkout --quiet -B main
(
  cd "$work"
  git rm -r --quiet --cached .
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
)
while IFS= read -r f; do
  [ -f "$ROOT/$f" ] || continue
  mkdir -p "$work/$(dirname "$f")"
  cp -p "$ROOT/$f" "$work/$f"
done < <(git -C "$ROOT" ls-files -co --exclude-standard)
to_v08_layout "$work"
(cd "$work" && $GIT add -A && { $GIT diff --cached --quiet || $GIT commit --quiet -m "fixture: this tree in the 0.8.0 layout"; })
UPSTREAM="$tmp/upstream.git"
git clone --quiet --bare "$work" "$UPSTREAM"

# The README route clones upstream and follows its sync body: Claude Code
# reads .claude/skills/sync-upstream/SKILL.md, Codex the source. One body.
git clone --quiet "$UPSTREAM" "$tmp/fresh"
FRESH_DOC="$tmp/fresh/.agents/skills/sync-upstream/SKILL.md"
check "the fresh clone's Claude and Codex sync bodies are one file" \
  cmp -s "$FRESH_DOC" "$tmp/fresh/.claude/skills/sync-upstream/SKILL.md"
load_doc "$FRESH_DOC"
[ -n "$INVENTORY" ] && [ -n "$APPLY" ] || { echo "FAIL: the sync body has no retirement snippets"; exit 1; }
NEW_ALLOWLIST=("${ALLOWLIST[@]}")
case " ${NEW_ALLOWLIST[*]} " in
  *" .claude/skills/ "*" "*) ;;
  *) bad "the fresh sync allowlist lacks .claude/skills/" ;;
esac
case " ${NEW_ALLOWLIST[*]} " in
  *" .claude/commands/ "*) ;;
  *) bad "the fresh sync allowlist dropped .claude/commands/ (retirement discovery needs it)" ;;
esac

# The inventory is exactly the 0.7.0 command set: 17 shared workflows plus ask-codex.
want_inventory="$(git ls-tree --name-only v0.7.0 -- .claude/commands/ | sed 's#^\.claude/commands/##; s#\.md$##' | LC_ALL=C sort | tr '\n' ' ')"
got_inventory="$(printf '%s\n' "$INVENTORY" | sed -n 's/^for n in \(.*\); do$/\1/p' | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')"
[ -n "$got_inventory" ] && [ "$got_inventory" = "$want_inventory" ] && ok "the retirement inventory is the 0.7.0 command set" ||
  bad "the retirement inventory is '$got_inventory', want '$want_inventory'"
[ "$(printf '%s\n' "$want_inventory" | wc -w | tr -d ' ')" = 18 ] && ok "the inventory has 18 workflows" || bad "the 0.7.0 command set is not 18 workflows"

# Every add/delete discovery diff in the body passes --no-renames.
renames="$(grep -n 'git diff' "$FRESH_DOC" | grep -E -e '--diff-filter|--stat|--name-only' | grep -v -e '--no-renames' || true)"
[ -z "$renames" ] && ok "every discovery diff in the body passes --no-renames" ||
  { bad "discovery diffs without --no-renames:"; printf '%s\n' "$renames" | sed 's/^/       /'; }

UPSTREAM_MAIN="$(git -C "$UPSTREAM" rev-parse main)"

# --- A downstream project ------------------------------------------------------
# scaffold <tag> <dir>: the tag's tree, fresh history, anchored at the tag with
# extra keys, plus the user's own content: bank and .rules lines, a project-only
# deploy workflow, a tracked Kit polish pack and a local, ignored Kit skill.
scaffold() {
  local tag="$1" P="$2"
  mkdir -p "$P"
  git -C "$ROOT" archive --format=tar "$tag" | tar -x -C "$P"
  (
    cd "$P"
    $GIT init --quiet
    printf '{ "upstream": "local/serel-memory", "ref": "%s", "linked": false,\n  "scopes": ["projects"], "nested": { "ref": "keep-me" } }\n' "$tag" > .serel-memory.json
    mkdir -p projects/widget .agents/skills/deploy .agents/skills/polish .claude/skills/polish .claude/commands
    echo "scope marker" > projects/widget/README.md
    echo "## Current focus: shipping the downstream widget" >> memory-bank/activeContext.md
    echo "- USER LEARNING: keep this line" >> .rules
    echo "# /deploy — the project's own command" > .claude/commands/deploy.md
    printf -- '---\nname: deploy\ndescription: "Deploy this project."\n---\n\n# Deploy\n' > .agents/skills/deploy/SKILL.md
    echo "# /polish — Serel Kit, shared install" > .claude/commands/polish.md
    printf -- '---\nname: polish\ndescription: "Polish prose."\n---\n\n# Polish\n' > .agents/skills/polish/SKILL.md
    echo '{ "kit": "0.3.0", "packs": ["writing"] }' > .serel-kit.json
    printf -- '---\nname: polish\ndescription: "Polish prose (local Kit)."\n---\n\n# Polish\n' > .claude/skills/polish/SKILL.md
    echo '/.claude/skills/polish/' >> .git/info/exclude
    $GIT add -A
    $GIT commit --quiet -m "scaffold from Serel Memory $tag, plus the project's own files"
  )
}

PROTECTED=(memory-bank .rules CLAUDE.md projects .claude/commands/deploy.md .agents/skills/deploy
  .claude/commands/polish.md .agents/skills/polish .claude/skills/polish .serel-kit.json)
snapshot() { # project -> checksums of everything sync must never touch
  local p
  (
    cd "$1"
    for p in "${PROTECTED[@]}"; do
      [ -e "$p" ] || continue
      find "$p" -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum < "$f")" "$f"; done
    done
  )
}

# --- The documented sync, mechanically ----------------------------------------
# sync_run <project> <doc> <label>: steps 1-10 of that body with the simulated
# user's choices. Results land in $P.out/: inventory, changed, absent, removed,
# conflicts, apply. Never commits.
sync_run() {
  local P="$1" doc="$2" label="$3" O="$1.out" out rc f n blob anchor_blob local_blob applied=0
  load_doc "$doc"
  rm -rf "$O"; mkdir -p "$O"
  : > "$O/inventory"; : > "$O/changed"; : > "$O/removed"; : > "$O/conflicts"; : > "$O/apply"
  (
    cd "$P/projects/widget"
    # Step 1 from a scope folder: the documented root cd brings it back.
    bash -c "cd \"\$(git rev-parse --show-toplevel)\" && $LEGACY" >/dev/null ||
      { echo "FAIL $label: the legacy-anchor guard stopped a modern project"; exit 1; }
    if [ -n "$LOCAL_GUARD" ]; then
      bash -c "cd \"\$(git rev-parse --show-toplevel)\" && $LOCAL_GUARD" >/dev/null ||
        { echo "FAIL $label: the local-install guard stopped a shared install"; exit 1; }
    fi
  ) || { fail=1; return 0; }
  cd "$P"
  [ -z "$(git status --porcelain -- "${ALLOWLIST[@]}")" ] || { bad "$label: framework files not clean before sync"; cd "$ROOT"; return 0; }
  git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM"
  git fetch --quiet upstream main
  out="$(bash -c "$RESOLVE" 2>&1)"
  case "$out" in *"anchor resolves: "*) ANCHOR="${out##*anchor resolves: }" ;; *) ANCHOR="" ;; esac
  if [ -n "$RESTORE_GUARD" ]; then
    bash -c "$RESTORE_GUARD" >/dev/null 2>&1 || { bad "$label: the restore guard stopped a tracked install"; cd "$ROOT"; return 0; }
  fi
  if [ -n "$ANCHOR" ]; then
    git diff $RN --name-only --diff-filter=d "$ANCHOR" upstream/main -- "${ALLOWLIST[@]}" > "$O/changed"
    git diff $RN --name-only --diff-filter=D "$ANCHOR" upstream/main -- "${ALLOWLIST[@]}" > "$O/removed"
  fi
  git diff $RN --name-only --diff-filter=A HEAD upstream/main -- "${ALLOWLIST[@]}" > "$O/absent"
  if [ -n "$INVENTORY" ]; then
    rc=0
    ANCHOR="$ANCHOR" bash -c "$INVENTORY" > "$O/inventory" 2>&1 || rc=$?
    [ "$rc" = 0 ] || bad "$label: the retirement inventory exited $rc"
  fi
  sed -n 's/^HOLD \([^ ]*\) .*/\1/p' "$O/inventory" > "$O/held"
  sed -n 's/^RETIRE \([^ ]*\) (blob \([0-9a-f]*\)).*/\1 \2/p' "$O/inventory" > "$O/retire"
  # Steps 8-9: pull all safe changes, one file at a time. Held workflows and
  # the skills that come with a retirement stay out; a locally modified file
  # (template mode: HEAD differs from the anchor) is a conflict, skipped.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    held_hit=0
    while IFS= read -r n; do
      case "$f" in ".claude/skills/$n/"*|".agents/skills/$n/"*) held_hit=1 ;; esac
    done < "$O/held"
    while IFS=' ' read -r n blob; do
      [ "$f" = ".claude/skills/$n/SKILL.md" ] && held_hit=1
    done < "$O/retire"
    [ "$held_hit" = 0 ] || continue
    if [ -e "$f" ]; then
      local_blob="$(git rev-parse -q --verify "HEAD:$f" || true)"
      [ "$local_blob" != "$(git rev-parse -q --verify "upstream/main:$f")" ] || continue
      anchor_blob="$( [ -n "$ANCHOR" ] && git rev-parse -q --verify "$ANCHOR:$f" || true)"
      if [ -z "$local_blob" ] || [ "$local_blob" != "$anchor_blob" ]; then echo "$f" >> "$O/conflicts"; continue; fi
    fi
    git restore --source=upstream/main -- "$f"
    applied=$((applied + 1))
  done < <(LC_ALL=C sort -u "$O/changed" "$O/absent")
  # Retire every matched command: the skill first, then the rechecked deletion.
  while IFS=' ' read -r n blob; do
    [ -n "$n" ] || continue
    [ -f ".claude/skills/$n/SKILL.md" ] || git restore --source=upstream/main -- ".claude/skills/$n/SKILL.md"
    if n="$n" blob="$blob" bash -c "$APPLY" >> "$O/apply" 2>&1; then applied=$((applied + 1)); else bad "$label: retiring $n failed"; fi
  done < "$O/retire"
  # Step 10: advance the anchor only for an applied change.
  if [ "$applied" -gt 0 ]; then
    bash -c "$UPDATE" || bad "$label: the anchor update failed"
  fi
  git update-ref -d refs/serel-memory/anchor 2>/dev/null || true
  cd "$ROOT"
}

user_commit() { (cd "$1" && $GIT add -A && $GIT commit --quiet -m "${2:-reviewed sync}"); }

# --- Assertions ------------------------------------------------------------------
# assert_untouched <project> <before-snapshot> <label>
assert_untouched() {
  [ "$(snapshot "$1")" = "$2" ] && ok "$3: bank, .rules, CLAUDE.md, project and Kit files untouched" ||
    bad "$3: sync changed a protected file"
  local O="$1.out"
  if LC_ALL=C sort -u "$O/changed" "$O/absent" "$O/removed" "$O/inventory" | grep -E 'polish|deploy|memory-bank|\.rules|CLAUDE\.md' >/dev/null; then
    bad "$3: a project, Kit or memory path appeared in discovery or the inventory"
  else
    ok "$3: discovery and the inventory never name project, Kit or memory paths"
  fi
}

assert_anchor() { # project label
  local P="$1"
  [ "$(jq -r .ref "$P/.serel-memory.json")" = "$UPSTREAM_MAIN" ] && [ "$(jq -r .linked "$P/.serel-memory.json")" = false ] &&
    [ "$(jq -c .scopes "$P/.serel-memory.json")" = '["projects"]' ] && [ "$(jq -r .nested.ref "$P/.serel-memory.json")" = keep-me ] &&
    ok "$2: anchor advanced, extra keys kept" || bad "$2: anchor is $(tr -d '\n' < "$P/.serel-memory.json")"
}

# assert_migrated <project> <label> [held workflow...]: every upstream framework
# file is in place and equal to upstream (held workflows excepted), no
# inventory command is left but the held ones, and nothing was committed.
assert_migrated() {
  local P="$1" label="$2" f n bad_files="" left
  shift 2
  local held=" $* "
  while IFS= read -r f; do
    n=""
    case "$f" in .claude/skills/*/*|.agents/skills/*/*) n="${f#.*/skills/}"; n="${n%%/*}" ;; esac
    case "$held" in *" $n "*) [ -n "$n" ] && continue ;; esac
    [ "$(git -C "$P" hash-object -- "$f" 2>/dev/null)" = "$(git -C "$P" rev-parse "upstream/main:$f")" ] || bad_files="$bad_files $f"
  done < <(git -C "$P" ls-tree -r --name-only upstream/main -- "${NEW_ALLOWLIST[@]}")
  [ -z "$bad_files" ] && ok "$label: every upstream framework file is in place" || bad "$label: missing or different:$bad_files"
  left="$(cd "$P" && for n in $want_inventory; do if [ -e ".claude/commands/$n.md" ]; then printf '%s ' "$n"; fi; done)"
  left="${left% }"
  if [ "$left" = "$*" ]; then ok "$label: inventory commands left: ${left:-none}"; else bad "$label: inventory commands left: '$left', want '$*'"; fi
  [ "$(git -C "$P" rev-list --count HEAD)" = "$(cat "$P.commits")" ] && ok "$label: nothing committed" || bad "$label: sync committed"
  if git -C "$P" diff --cached --name-only | grep -q .; then bad "$label: sync staged changes"; else ok "$label: nothing staged; retirements are worktree deletions"; fi
}

# assert_no_drift <project> <label> [allowed]: the project's own (new) checker,
# after the user commits, reports nothing about Kit or project files, nothing
# shadowed, and no framework workflow finding but the [allowed] ones (an ERE:
# a deliberate customization). Bank templates are the scaffold's and may be DRIFT.
assert_no_drift() {
  local P="$1" out allowed="${3:-^$}"
  out="$(cd "$P" && bash bin/serel-memory check 2>&1 || true)"
  if printf '%s\n' "$out" | grep -E 'polish|deploy' >/dev/null; then
    bad "$2: the checker reports Kit or project files:"; printf '%s\n' "$out" | grep -E 'polish|deploy' | sed 's/^/       /'
  else ok "$2: no drift findings for Kit or project files"; fi
  if printf '%s\n' "$out" | grep -E '^(DRIFT|INFO|INCOMPLETE|STALE|WARN) \.(claude|agents)/' | grep -Ev "$allowed" >/dev/null; then
    bad "$2: the checker reports framework workflows:"; printf '%s\n' "$out" | grep -E '^[A-Z]+ \.(claude|agents)/' | sed 's/^/       /'
  else ok "$2: no framework workflow findings${3:+ beyond the customized ones}"; fi
  printf '%s\n' "$out" | grep -q "baseline: $UPSTREAM_MAIN" && ok "$2: the checker compared against the synced commit" ||
    bad "$2: the checker did not compare against $UPSTREAM_MAIN: $(printf '%s\n' "$out" | tail -1)"
  CHECK_OUT="$out"
}

begin() { # tag dir -> scaffolds, records the commit count and the protected snapshot
  scaffold "$1" "$2"
  git -C "$2" rev-list --count HEAD > "$2.commits"
  BEFORE="$(snapshot "$2")"
}

# =============================================================================
# 1. README route, unmodified projects, from v0.3.0, v0.6.0 and v0.7.0
# =============================================================================
for tag in v0.3.0 v0.6.0 v0.7.0; do
  P="$tmp/readme-$tag"
  begin "$tag" "$P"
  sync_run "$P" "$FRESH_DOC" "README route from $tag"
  O="$P.out"
  n_cmd="$(git -C "$ROOT" ls-tree --name-only "$tag" -- .claude/commands/ | wc -l | tr -d ' ')"
  [ "$(grep -c '^RETIRE ' "$O/inventory")" = "$n_cmd" ] && ! grep -qv '^RETIRE ' "$O/inventory" &&
    ok "README route from $tag: all $n_cmd shipped commands offered for retirement" ||
    { bad "README route from $tag: inventory"; sed 's/^/       /' "$O/inventory"; }
  [ "$(grep -c '^RETIRED ' "$O/apply")" = "$n_cmd" ] && ok "README route from $tag: $n_cmd commands retired after the recheck" ||
    { bad "README route from $tag: retirements"; sed 's/^/       /' "$O/apply"; }
  [ ! -s "$O/conflicts" ] && ok "README route from $tag: no conflicts in an unmodified project" ||
    { bad "README route from $tag: conflicts"; sed 's/^/       /' "$O/conflicts"; }
  grep -q '^\.claude/commands/' "$O/removed" && grep -qx '.claude/skills/ship/SKILL.md' "$O/changed" &&
    grep -qx '.claude/skills/ship/SKILL.md' "$O/absent" && ok "README route from $tag: discovery sees each command's deletion and each skill's addition" ||
    bad "README route from $tag: discovery missed the move"
  assert_migrated "$P" "README route from $tag"
  deleted="$(git -C "$P" status --porcelain -- .claude/commands/ | grep -c '^ D ' || true)"
  [ "$deleted" = "$n_cmd" ] && ok "README route from $tag: retirements are unstaged deletions" || bad "README route from $tag: $deleted unstaged deletions, want $n_cmd"
  assert_anchor "$P" "README route from $tag"
  assert_untouched "$P" "$BEFORE" "README route from $tag"
  user_commit "$P"
  assert_no_drift "$P" "README route from $tag"
  # A second run changes nothing: nothing pending, no command left to retire.
  begin_commits="$(git -C "$P" rev-parse HEAD)"
  sync_run "$P" "$FRESH_DOC" "README route from $tag, second run"
  grep -qx 'RETIREMENT: no inventory command left in .claude/commands/' "$P.out/inventory" && [ -z "$(git -C "$P" status --porcelain)" ] &&
    [ "$(git -C "$P" rev-parse HEAD)" = "$begin_commits" ] && ok "README route from $tag: a second run finds nothing to do" ||
    { bad "README route from $tag: the second run changed something"; git -C "$P" status --porcelain | sed 's/^/       /'; }
done

# The v0.3.0 start: its CLAUDE.md shim is project-owned and only a candidate.
[ -f "$tmp/readme-v0.3.0/CLAUDE.md" ] && cmp -s "$tmp/readme-v0.3.0/CLAUDE.md" <(git -C "$ROOT" show v0.3.0:CLAUDE.md) &&
  ok "README route from v0.3.0: the CLAUDE.md shim is left for its own review" || bad "README route from v0.3.0: CLAUDE.md changed"

# =============================================================================
# 2. Installed Codex sync, two runs, from v0.6.0 and v0.7.0
# =============================================================================
for tag in v0.6.0 v0.7.0; do
  P="$tmp/codex-$tag"
  begin "$tag" "$P"
  # Run 1: the project's own 0.6.0/0.7.0 Codex body.
  sync_run "$P" "$P/.agents/skills/sync-upstream/SKILL.md" "Codex run 1 from $tag"
  n_cmd="$(git -C "$ROOT" ls-tree --name-only "$tag" -- .claude/commands/ | wc -l | tr -d ' ')"
  left="$(find "$P/.claude/commands" -name '*.md' | wc -l | tr -d ' ')"
  [ "$left" = "$((n_cmd + 2))" ] && ok "Codex run 1 from $tag: the old body deletes no command" || bad "Codex run 1 from $tag: $left commands left, want $((n_cmd + 2))"
  [ ! -e "$P/.claude/skills/ship" ] && ok "Codex run 1 from $tag: the old allowlist adds no Claude skill" || bad "Codex run 1 from $tag: a Claude skill appeared"
  cmp -s "$P/.agents/skills/sync-upstream/SKILL.md" "$FRESH_DOC" && ok "Codex run 1 from $tag: the new sync body is installed" ||
    bad "Codex run 1 from $tag: the sync body was not updated"
  assert_anchor "$P" "Codex run 1 from $tag"
  user_commit "$P" "reviewed sync, run 1"
  git -C "$P" rev-list --count HEAD > "$P.commits"
  # Run 2: the body run 1 installed, reloaded.
  sync_run "$P" "$P/.agents/skills/sync-upstream/SKILL.md" "Codex run 2 from $tag"
  O="$P.out"
  [ "$(grep -c '^RETIRE ' "$O/inventory")" = "$n_cmd" ] && ! grep -qv '^RETIRE ' "$O/inventory" &&
    ok "Codex run 2 from $tag: every command offered, though the anchor already moved" ||
    { bad "Codex run 2 from $tag: inventory"; sed 's/^/       /' "$O/inventory"; }
  [ ! -s "$O/changed" ] && ok "Codex run 2 from $tag: the anchor diff is empty (retirement does not depend on it)" || bad "Codex run 2 from $tag: anchor diff not empty"
  assert_migrated "$P" "Codex run 2 from $tag"
  assert_anchor "$P" "Codex run 2 from $tag"
  assert_untouched "$P" "$BEFORE" "Codex two runs from $tag"
  user_commit "$P"
  assert_no_drift "$P" "Codex two runs from $tag"
done

# The two runs with customizations: a customized ship command and a customized
# Codex handoff skill. Run 1 (the old body) keeps the command (review only)
# and skips the Codex conflict; run 2 holds both workflows, each with its
# Claude skill, Codex skill and retirement, and retires the other 16.
P="$tmp/codex-custom"
begin v0.7.0 "$P"
echo "PROJECT RULE: ship only on Fridays." >> "$P/.claude/commands/ship.md"
echo "CODEX RULE: hand off in the PR description." >> "$P/.agents/skills/handoff/SKILL.md"
user_commit "$P" "customize ship (Claude) and handoff (Codex)"
BEFORE="$(snapshot "$P")"
cp "$P/.claude/commands/ship.md" "$tmp/codex-ship"
cp "$P/.agents/skills/handoff/SKILL.md" "$tmp/codex-handoff"
sync_run "$P" "$P/.agents/skills/sync-upstream/SKILL.md" "customized Codex run 1"
cmp -s "$P/.claude/commands/ship.md" "$tmp/codex-ship" && cmp -s "$P/.agents/skills/handoff/SKILL.md" "$tmp/codex-handoff" &&
  ok "customized Codex run 1: the customized command stays, the customized Codex skill is not overwritten" || bad "customized Codex run 1"
user_commit "$P" "reviewed sync, run 1"
git -C "$P" rev-list --count HEAD > "$P.commits"
sync_run "$P" "$P/.agents/skills/sync-upstream/SKILL.md" "customized Codex run 2"
O="$P.out"
grep -q '^HOLD ship (blob [0-9a-f]*): unknown bytes in .claude/commands/ship.md;' "$O/inventory" &&
  grep -q '^HOLD handoff (blob [0-9a-f]*): unknown bytes in .agents/skills/handoff/SKILL.md;' "$O/inventory" &&
  [ "$(grep -c '^RETIRE ' "$O/inventory")" = 16 ] &&
  ok "customized Codex run 2: ship and handoff held, the other 16 offered" || { bad "customized Codex run 2: inventory"; sed 's/^/       /' "$O/inventory"; }
cmp -s "$P/.claude/commands/ship.md" "$tmp/codex-ship" && cmp -s "$P/.agents/skills/handoff/SKILL.md" "$tmp/codex-handoff" &&
  [ ! -e "$P/.claude/skills/ship" ] && [ ! -e "$P/.claude/skills/handoff" ] && [ -f "$P/.claude/commands/handoff.md" ] &&
  ok "customized Codex run 2: both held workflows stay exactly as they were" || bad "customized Codex run 2: a held file changed"
assert_migrated "$P" "customized Codex run 2" handoff ship
assert_untouched "$P" "$BEFORE" "customized Codex two runs"

# =============================================================================
# 3. A customized ship command (README route, v0.7.0 and v0.3.0)
# =============================================================================
for tag in v0.7.0 v0.3.0; do
  P="$tmp/ship-$tag"
  begin "$tag" "$P"
  echo "PROJECT RULE: ship only on Fridays." >> "$P/.claude/commands/ship.md"
  user_commit "$P" "customize ship"
  git -C "$P" rev-list --count HEAD > "$P.commits"
  BEFORE="$(snapshot "$P")"
  cp "$P/.claude/commands/ship.md" "$tmp/ship-custom-$tag"
  codex_ship="$(git -C "$P" rev-parse HEAD:.agents/skills/ship/SKILL.md)"
  sync_run "$P" "$FRESH_DOC" "customized ship from $tag"
  O="$P.out"
  grep -q '^HOLD ship (blob [0-9a-f]*): unknown bytes in .claude/commands/ship.md; hold .claude/skills/ship/SKILL.md, .agents/skills/ship/SKILL.md and the retirement of .claude/commands/ship.md together$' "$O/inventory" &&
    ok "customized ship from $tag: held, with its skill, Codex skill and retirement" || { bad "customized ship from $tag: not held"; sed 's/^/       /' "$O/inventory"; }
  cmp -s "$P/.claude/commands/ship.md" "$tmp/ship-custom-$tag" && [ ! -e "$P/.claude/skills/ship" ] &&
    [ "$(git -C "$P" hash-object .agents/skills/ship/SKILL.md)" = "$codex_ship" ] &&
    ok "customized ship from $tag: the command, the Codex skill and the missing Claude skill all stay as they were" ||
    bad "customized ship from $tag: a held file changed"
  assert_migrated "$P" "customized ship from $tag" ship
  assert_untouched "$P" "$BEFORE" "customized ship from $tag"
  # The recheck: a command changed after it was shown, or left uncommitted, is never deleted.
  shown="$(sed -n 's/^HOLD ship (blob \([0-9a-f]*\)).*/\1/p' "$O/inventory")"
  (
    cd "$P"
    mkdir -p .claude/skills/ship
    { git show upstream/main:.claude/skills/ship/SKILL.md; echo "PROJECT RULE: ship only on Fridays."; } > .claude/skills/ship/SKILL.md
    { git show upstream/main:.agents/skills/ship/SKILL.md; echo "PROJECT RULE: ship only on Fridays."; } > .agents/skills/ship/SKILL.md
    echo "one more edit" >> .claude/commands/ship.md
    if n=ship blob="$shown" bash -c "$APPLY" >/dev/null 2>&1; then exit 1; fi
    [ -f .claude/commands/ship.md ] || exit 1
    git restore -- .claude/commands/ship.md
    if n=ship blob="$(git hash-object .claude/commands/ship.md)" bash -c "$APPLY" >/dev/null 2>&1; then :; else exit 1; fi
    [ ! -e .claude/commands/ship.md ] || exit 1
  ) && ok "customized ship from $tag: ported, then retired; the recheck refused the edited bytes first" ||
    bad "customized ship from $tag: the port-then-retire path failed"
  (
    cd "$P"
    git restore -- .claude/commands/ship.md
    echo "uncommitted" >> .claude/commands/ship.md
    if n=ship blob="$(git hash-object .claude/commands/ship.md)" bash -c "$APPLY" >/dev/null 2>&1; then exit 1; fi
    [ -f .claude/commands/ship.md ] || exit 1
    git restore -- .claude/commands/ship.md
  ) && ok "customized ship from $tag: an uncommitted command is never deleted" || bad "customized ship from $tag: an uncommitted command was deleted"
done

# =============================================================================
# 4. Separately customized Claude and Codex handoff adapters (README route)
# =============================================================================
P="$tmp/handoff"
begin v0.7.0 "$P"
echo "CLAUDE RULE: hand off to the on-call channel." >> "$P/.claude/commands/handoff.md"
echo "CODEX RULE: hand off in the PR description." >> "$P/.agents/skills/handoff/SKILL.md"
user_commit "$P" "customize handoff per CLI"
git -C "$P" rev-list --count HEAD > "$P.commits"
BEFORE="$(snapshot "$P")"
cp "$P/.claude/commands/handoff.md" "$tmp/handoff-claude"
cp "$P/.agents/skills/handoff/SKILL.md" "$tmp/handoff-codex"
sync_run "$P" "$FRESH_DOC" "customized handoff"
O="$P.out"
grep -q '^HOLD handoff (blob [0-9a-f]*): unknown bytes in .claude/commands/handoff.md .agents/skills/handoff/SKILL.md;' "$O/inventory" &&
  ok "customized handoff: held, naming both customized adapters" || { bad "customized handoff: not held together"; sed 's/^/       /' "$O/inventory"; }
cmp -s "$P/.claude/commands/handoff.md" "$tmp/handoff-claude" && cmp -s "$P/.agents/skills/handoff/SKILL.md" "$tmp/handoff-codex" &&
  [ ! -e "$P/.claude/skills/handoff" ] && ok "customized handoff: neither replacement was written" || bad "customized handoff: a held file changed"
! grep -q 'handoff' "$O/conflicts" && ok "customized handoff: its files never reached the safe pull, not even as conflicts" ||
  bad "customized handoff: a held file reached the safe pull"
assert_migrated "$P" "customized handoff" handoff
assert_untouched "$P" "$BEFORE" "customized handoff"
# Resolve together: port each CLI's rule into its own copy, then retire.
shown="$(sed -n 's/^HOLD handoff (blob \([0-9a-f]*\)).*/\1/p' "$O/inventory")"
(
  cd "$P"
  mkdir -p .claude/skills/handoff
  { git show upstream/main:.claude/skills/handoff/SKILL.md; echo "CLAUDE RULE: hand off to the on-call channel."; } > .claude/skills/handoff/SKILL.md
  { git show upstream/main:.agents/skills/handoff/SKILL.md; echo "CODEX RULE: hand off in the PR description."; } > .agents/skills/handoff/SKILL.md
  n=handoff blob="$shown" bash -c "$APPLY" >/dev/null
) && [ ! -e "$P/.claude/commands/handoff.md" ] && ok "customized handoff: ported per CLI, then retired" || bad "customized handoff: port and retire failed"
user_commit "$P"
assert_no_drift "$P" "customized handoff" '^INFO \.(claude|agents)/skills/handoff/SKILL\.md '
printf '%s\n' "$CHECK_OUT" | grep -q '^INFO .claude/skills/handoff/SKILL.md the Claude and Codex copies differ' &&
  ok "customized handoff: the checker notes the copies differ, as INFO" || bad "customized handoff: no copies-differ note"
cmp -s "$P/.claude/skills/handoff/SKILL.md" "$P/.agents/skills/handoff/SKILL.md" && bad "customized handoff: the copies were consolidated" ||
  ok "customized handoff: the copies stay different per CLI"

# =============================================================================
# 5. An anchor already advanced to 0.8.0, with the commands left behind
# =============================================================================
P="$tmp/advanced"
begin v0.7.0 "$P"
(
  cd "$P"
  git remote add upstream "$UPSTREAM"
  git fetch --quiet upstream main
  # An earlier sync pulled every file but retired nothing.
  git ls-tree -r --name-only upstream/main -- "${NEW_ALLOWLIST[@]}" | while IFS= read -r f; do
    git restore --source=upstream/main -- "$f"
  done
  tmpj="$(mktemp)"
  jq --arg ref "$(git rev-parse upstream/main)" '.ref = $ref' .serel-memory.json > "$tmpj" && mv "$tmpj" .serel-memory.json
)
user_commit "$P" "an earlier sync that left the commands"
git -C "$P" rev-list --count HEAD > "$P.commits"
BEFORE="$(snapshot "$P")"
out="$(cd "$P" && bash bin/serel-memory check 2>&1 || true)"
n_shadow="$(printf '%s\n' "$out" | grep -c '^INFO \.claude/commands/[a-z-]*\.md shadowed by \.claude/skills/' || true)"
[ "$n_shadow" = 18 ] && ok "advanced anchor: the checker reports all 18 Memory commands as shadowed" ||
  { bad "advanced anchor: $n_shadow shadowed notes, want 18"; printf '%s\n' "$out" | sed 's/^/       /'; }
printf '%s\n' "$out" | grep -q 'polish' && bad "advanced anchor: the checker reports the Kit command as shadowed" ||
  ok "advanced anchor: the Kit command and local Kit skill are not reported"
sync_run "$P" "$FRESH_DOC" "advanced anchor"
O="$P.out"
[ ! -s "$O/changed" ] && [ "$(grep -c '^RETIRE ' "$O/inventory")" = 18 ] &&
  ok "advanced anchor: an empty anchor diff, and all 18 retirements still offered" || { bad "advanced anchor: inventory"; sed 's/^/       /' "$O/inventory"; }
assert_migrated "$P" "advanced anchor"
assert_untouched "$P" "$BEFORE" "advanced anchor"
user_commit "$P"
assert_no_drift "$P" "advanced anchor"

# =============================================================================
# 6. Rename-shaped upstream history
# =============================================================================
# Upstream moves ship's command to the skill path unchanged — a pure rename —
# and still ships every other command. Rename detection would fold the
# deletion and the addition into one R entry that both discovery lists miss.
rw="$tmp/rename-work"
git clone --quiet "$ROOT" "$rw"
(
  cd "$rw"
  git checkout --quiet -B main v0.7.0
  mkdir -p .claude/skills/ship
  git mv .claude/commands/ship.md .claude/skills/ship/SKILL.md
  $GIT commit --quiet -m "move ship to a skill, unchanged"
)
git clone --quiet --bare "$rw" "$tmp/upstream-rename.git"
P="$tmp/rename"
begin v0.7.0 "$P"
(
  cd "$P"
  git remote add upstream "$tmp/upstream-rename.git"
  git fetch --quiet upstream main
  git fetch --quiet --no-tags upstream "+refs/tags/v0.7.0:refs/serel-memory/anchor"
)
A="refs/serel-memory/anchor"
renamed_add="$(git -C "$P" -c diff.renames=true diff -M --name-only --diff-filter=A HEAD upstream/main -- "${NEW_ALLOWLIST[@]}")"
renamed_del="$(git -C "$P" -c diff.renames=true diff -M --name-only --diff-filter=D "$A" upstream/main -- "${NEW_ALLOWLIST[@]}")"
[ -z "$renamed_add" ] && [ -z "$renamed_del" ] && ok "rename fixture: with rename detection, neither list sees the move" ||
  bad "rename fixture invalid: rename detection still listed '$renamed_add' / '$renamed_del'"
plain_add="$(git -C "$P" -c diff.renames=true diff --no-renames --name-only --diff-filter=A HEAD upstream/main -- "${NEW_ALLOWLIST[@]}")"
plain_del="$(git -C "$P" -c diff.renames=true diff --no-renames --name-only --diff-filter=D "$A" upstream/main -- "${NEW_ALLOWLIST[@]}")"
[ "$plain_add" = .claude/skills/ship/SKILL.md ] && [ "$plain_del" = .claude/commands/ship.md ] &&
  ok "rename-shaped history: --no-renames discovers the addition and the deletion" || bad "rename-shaped history: '$plain_add' / '$plain_del'"
inv="$(cd "$P" && ANCHOR="$A" bash -c "$INVENTORY" 2>&1)"
printf '%s\n' "$inv" | grep -q '^RETIRE ship (blob ' && [ "$(printf '%s\n' "$inv" | grep -c '^SKIP ')" = 17 ] &&
  ok "rename-shaped history: the inventory offers ship and skips the 17 workflows upstream still ships as commands" ||
  { bad "rename-shaped history: inventory"; printf '%s\n' "$inv" | sed 's/^/       /'; }

# =============================================================================
# 7. Shells, a shallow clone, and no upstream/main
# =============================================================================
# Agents run these snippets in whatever shell they have: bash 3.2 on macOS,
# sh (dash) on Linux, zsh by default on macOS. Same output everywhere.
P="$tmp/shells"
begin v0.7.0 "$P"
(cd "$P" && git remote add upstream "$UPSTREAM" && git fetch --quiet upstream main)
echo "PROJECT RULE" >> "$P/.claude/commands/review.md"
user_commit "$P" "customize review"
ref_out="$(cd "$P" && bash -c "$INVENTORY" 2>&1)"
for sh in sh zsh; do
  command -v "$sh" >/dev/null 2>&1 || { echo "     ($sh not installed: skipped)"; continue; }
  [ "$(cd "$P" && "$sh" -c "$INVENTORY" 2>&1)" = "$ref_out" ] && ok "the inventory reads the same in $sh" || bad "the inventory differs in $sh"
done
printf '%s\n' "$ref_out" | grep -q '^HOLD review ' && [ "$(printf '%s\n' "$ref_out" | grep -c '^RETIRE ')" = 17 ] &&
  ok "shells fixture: one customized command held, 17 matched" || bad "shells fixture: unexpected inventory"
blob="$(git -C "$P" hash-object "$P/.claude/commands/start.md")"
for sh in sh zsh; do
  command -v "$sh" >/dev/null 2>&1 || continue
  (cd "$P" && git restore --source=upstream/main -- .claude/skills/start/SKILL.md && n=start blob="$blob" "$sh" -c "$APPLY" >/dev/null) &&
    [ ! -e "$P/.claude/commands/start.md" ] && ok "the apply snippet works in $sh" || bad "the apply snippet failed in $sh"
  git -C "$P" restore -- .claude/commands/start.md
  rm -rf "$P/.claude/skills/start"
done

# A shallow clone: history may be cut short, so no bytes count as known.
P="$tmp/shallow-src"
begin v0.7.0 "$P"
git clone --quiet --bare "$P" "$tmp/shallow-origin.git"
git clone --quiet --depth 1 "file://$tmp/shallow-origin.git" "$tmp/shallow"
(cd "$tmp/shallow" && git remote add upstream "$UPSTREAM" && git fetch --quiet upstream main)
[ "$(git -C "$tmp/shallow" rev-parse --is-shallow-repository)" = true ] || bad "shallow fixture is not shallow"
inv="$(cd "$tmp/shallow" && bash -c "$INVENTORY" 2>&1)" && rc=0 || rc=$?
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$inv" | grep -c '^HOLD .*(shallow clone: run git fetch --unshallow, then sync again)')" = 18 ] &&
  ! printf '%s\n' "$inv" | grep -q '^RETIRE' && ok "a shallow clone holds every command" ||
  { bad "shallow clone: rc $rc"; printf '%s\n' "$inv" | sed 's/^/       /'; }

# No upstream/main at all: everything held, and the snippet says it failed.
(cd "$tmp/shallow" && git update-ref -d refs/remotes/upstream/main)
inv="$(cd "$tmp/shallow" && bash -c "$INVENTORY" 2>&1)" && rc=0 || rc=$?
[ "$rc" = 1 ] && [ "$(printf '%s\n' "$inv" | grep -c '^HOLD .*(upstream/main does not resolve)')" = 18 ] &&
  ok "no upstream/main: every command held, exit 1" || { bad "no upstream/main: rc $rc"; printf '%s\n' "$inv" | sed 's/^/       /'; }

# A symlinked or untracked inventory command is held, never matched.
P="$tmp/odd"
begin v0.7.0 "$P"
(
  cd "$P"
  git remote add upstream "$UPSTREAM" && git fetch --quiet upstream main
  git rm -q --cached .claude/commands/retro.md
  echo '/.claude/commands/retro.md' >> .git/info/exclude
  rm .claude/commands/runbook.md && ln -s start.md .claude/commands/runbook.md
)
inv="$(cd "$P" && bash -c "$INVENTORY" 2>&1)"
printf '%s\n' "$inv" | grep -q '^HOLD retro ' && printf '%s\n' "$inv" | grep -q '^HOLD runbook ' &&
  ok "an untracked or symlinked command is held, never matched" || { bad "odd commands"; printf '%s\n' "$inv" | sed 's/^/       /'; }

if [ "$fail" -eq 0 ]; then
  echo "migration OK: 0.3.0, 0.6.0 and 0.7.0 projects reach the 0.8.0 layout; customized workflows are held, Kit and project files untouched"
fi
exit "$fail"
