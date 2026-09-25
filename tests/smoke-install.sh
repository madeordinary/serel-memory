#!/usr/bin/env bash
# End-to-end test of `install.sh --local` against real repositories in a temp
# directory. The installer runs from a fixture checkout built from this working
# tree (tracked files plus new, non-ignored ones), so the test covers what is on
# disk whether or not it is committed yet.
#
# Cases:
#   1. The preview writes nothing, to the target or the source. Apply leaves
#      tracked, staged and untracked work, the index and `git status` exactly
#      as they were; it installs the declared payload only, writes exact
#      exclude lines, and the anchor names the clean release tag.
#   2. Re-running changes nothing and keeps the user's bank and .rules.
#   3. A tracked destination, a tracked bank, a differing untracked file or an
#      unknown file in memory-bank/ stops preview and apply with zero writes.
#   4. An existing AGENTS.md (with CLAUDE.md) stays intact and unexcluded.
#   5. An ignore negation, in .gitignore or info/exclude, is refused, and so
#      is one that keeps the memory-bank/ folder visible while each template
#      is ignored; one only the created folder reveals is rolled back.
#   6. A linked worktree: exclusions go to the shared info/exclude, the files
#      stay in that worktree, and a second install adds no duplicate lines.
#   7. Source/target safety: same or nested source and target, a subdirectory
#      target, a copy that is not a checkout, symlinks, hard links, a nested
#      repository, and a missing --local.
#   8. An ordinary copy failure rolls back every file and the exclusions,
#      including an info/ directory the run created.
#   9. Provenance: uncommitted payload changes give a linked anchor; a clean
#      untagged commit gives its SHA, and so does a tag that is not
#      release-shaped (the anchor stays valid JSON).
#  10. Case: a tracked name that matches a destination, a directory on the
#      way, the bank or the anchor only when case is ignored is refused on any
#      filesystem; a tracked `agents.md` counts as existing instructions. On a
#      case-insensitive filesystem, an existing untracked name stored with
#      other capitalization is refused too.
#
# What this does not prove: that Claude Code or Codex discover the installed
# workflows. tests/local-setup-acceptance.md is that exercise.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
export GIT_OPTIONAL_LOCKS=0

fail=0
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

G=(git -c user.email=smoke@test -c user.name=smoke-install -c commit.gpgsign=false)

# --- fixtures ----------------------------------------------------------------

src="$tmp/source"
mkdir "$src"
while IFS= read -r f; do
  [ -f "$ROOT/$f" ] || continue
  mkdir -p "$src/$(dirname "$f")"
  cp -p "$ROOT/$f" "$src/$f"
done < <(git -C "$ROOT" ls-files -co --exclude-standard)
"${G[@]}" init -q "$src"
"${G[@]}" -C "$src" add -A
"${G[@]}" -C "$src" commit -qm "source fixture"
"${G[@]}" -C "$src" tag v9.9.9-fixture
INSTALL="$src/install.sh"
[ -f "$INSTALL" ] || { echo "FAIL: install.sh is missing from the working tree"; exit 1; }

# The declared payload: the sync allowlist plus the starter bank and .rules.
PAYLOAD_SPEC=(.agents/skills .claude/commands AGENTS.md docs/workflow-contract.md
  docs/cross-agent-review.md docs/serel-setup.md hooks bin/serel-memory memory-bank .rules)

new_repo() { # dir [git-init args...] -> a repository with one commit
  local dir="$1"
  shift
  "${G[@]}" init -q "$@" "$dir"
  printf '# Demo\n' >"$dir/README.md"
  mkdir "$dir/src"
  printf 'print(1)\n' >"$dir/src/app.py"
  "${G[@]}" -C "$dir" add -A
  "${G[@]}" -C "$dir" commit -qm init
}

# Every entry below the root, .git included, with type, mode and checksum.
snapshot() {
  (
    cd "$1" || exit 1
    find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then
        printf 'link %s -> %s\n' "$p" "$(readlink "$p")"
      elif [ -d "$p" ]; then
        printf 'dir  %s\n' "$p"
      elif [ -f "$p" ]; then
        if [ -x "$p" ]; then mode=x; else mode=-; fi
        printf 'file %s %s %s\n' "$mode" "$p" "$(cksum <"$p")"
      else
        printf 'other %s\n' "$p"
      fi
    done
  )
}

# What Git reports: status (untracked included), index, and both diffs.
git_state() {
  (
    cd "$1" || exit 1
    git status --porcelain=v1 --untracked-files=all
    git ls-files -s
    git diff
    git diff --cached
    cksum <"$(git rev-parse --git-path index)"
  )
}

# refused <label> <log> <pattern> <dir> <install args...>: preview and apply
# both exit non-zero, name the problem, and leave <dir> byte-identical.
refused() {
  local label="$1" log="$2" pattern="$3" dir="$4" before mode
  shift 4
  before="$(snapshot "$dir")"
  for mode in preview apply; do
    local extra=()
    [ "$mode" = preview ] || extra=(--apply)
    if bash "$INSTALL" "$@" ${extra[@]+"${extra[@]}"} >"$log.$mode" 2>&1; then
      bad "$label: $mode succeeded (expected a refusal)"
    fi
    grep -qF -- "$pattern" "$log.$mode" || { cat "$log.$mode"; bad "$label: $mode did not report '$pattern'"; }
    grep -q 'Nothing was written' "$log.$mode" || bad "$label: $mode did not say nothing was written"
    [ "$(snapshot "$dir")" = "$before" ] || bad "$label: $mode wrote to the target"
  done
}

# --- case 1: preview and apply ----------------------------------------------

echo "case 1: preview writes nothing; apply keeps existing work and git state"
t1="$tmp/work"
new_repo "$t1"
printf 'print(2)\n' >>"$t1/src/app.py"
printf 'staged\n' >"$t1/staged.txt"
git -C "$t1" add staged.txt
printf 'mine\n' >"$t1/notes.txt"
mkdir -p "$t1/.claude/commands" "$t1/docs"
printf '# my own command\n' >"$t1/.claude/commands/mine.md"
printf '# PRD\n' >"$t1/docs/prd.md"
existing=(README.md src/app.py staged.txt notes.txt .claude/commands/mine.md docs/prd.md)
sums() { (cd "$1" && for f in "${existing[@]}"; do cksum "$f"; done); }
before="$(snapshot "$t1")"
state="$(git_state "$t1")"
sums_before="$(sums "$t1")"
src_before="$(snapshot "$src")"

bash "$INSTALL" "$t1" --local >"$tmp/1.preview" 2>&1 || { cat "$tmp/1.preview"; bad "preview exited non-zero"; }
[ "$(snapshot "$t1")" = "$before" ] || bad "the preview wrote to the target"
[ "$(snapshot "$src")" = "$src_before" ] || bad "the preview wrote to the source checkout"
grep -q 'preview (nothing written)' "$tmp/1.preview" || bad "the preview did not say it wrote nothing"
grep -qx '  .claude/commands/start.md' "$tmp/1.preview" || bad "the preview did not list .claude/commands/start.md"
grep -qx '  /memory-bank/' "$tmp/1.preview" || bad "the preview did not list the bank exclusion"
grep -q 'git clean -x' "$tmp/1.preview" || bad "the preview did not state the durability limits"

bash "$INSTALL" "$t1" --local --apply >"$tmp/1.apply" 2>&1 || { cat "$tmp/1.apply"; bad "apply exited non-zero"; }
[ "$(git_state "$t1")" = "$state" ] || bad "apply changed git status, the index, or tracked/staged work"
[ "$(snapshot "$src")" = "$src_before" ] || bad "apply wrote to the source checkout"
[ "$(sums "$t1")" = "$sums_before" ] || bad "apply changed an existing file"
while IFS= read -r f; do
  cmp -s "$src/$f" "$t1/$f" || bad "installed file differs from the source: $f"
done < <(git -C "$src" ls-files -- "${PAYLOAD_SPEC[@]}")
if [ ! -x "$t1/bin/serel-memory" ] || [ ! -x "$t1/hooks/session-start.sh" ]; then
  bad "executable bits were not kept"
fi
for f in install.sh CHANGELOG.md CONTRIBUTING.md tests .github docs/research docs/decisions \
  .claude/settings.json .claude/settings.local.json .codex; do
  [ ! -e "$t1/$f" ] || bad "installed something outside the declared payload: $f"
done
grep -qxF '{ "upstream": "madeordinary/serel-memory", "ref": "v9.9.9-fixture", "linked": false }' "$t1/.serel-memory.json" ||
  bad "the anchor does not name the clean release tag: $(cat "$t1/.serel-memory.json")"

ex="$t1/.git/info/exclude"
[ "$(grep -c '^# Serel Memory local install' "$ex")" = 1 ] || bad "expected one installer comment in info/exclude"
for l in /.claude/commands/start.md /.agents/skills/start/SKILL.md /docs/serel-setup.md /bin/serel-memory \
  /memory-bank/ /.rules /.serel-memory.json /AGENTS.md; do
  grep -qxF -- "$l" "$ex" || bad "info/exclude lacks $l"
done
if grep -qxE '/?(\.claude|\.agents|docs|hooks|bin)(/|/\*)?' "$ex"; then
  bad "info/exclude hides a whole shared directory"
fi
git -C "$t1" check-ignore -q memory-bank/archive/activeContext-2026-09.md ||
  bad "a later bank file would not be ignored"
for f in .claude/commands/mine.md .claude/settings.json docs/handoff.md docs/prd.md; do
  if git -C "$t1" check-ignore -q "$f"; then bad "a user path is ignored: $f"; fi
done

# --- case 2: idempotence -----------------------------------------------------

echo "case 2: re-running changes nothing and keeps the bank"
printf '# Project Brief\n\nThe real project.\n' >"$t1/memory-bank/projectbrief.md"
printf -- '- a learning\n' >>"$t1/.rules"
printf '\nA local note.\n' >>"$t1/AGENTS.md"
mkdir -p "$t1/memory-bank/archive"
printf 'history\n' >"$t1/memory-bank/archive/activeContext-2026-09.md"
before="$(snapshot "$t1")"
for mode in "" --apply; do
  bash "$INSTALL" "$t1" --local ${mode:+"$mode"} >"$tmp/2.log" 2>&1 || { cat "$tmp/2.log"; bad "re-run ${mode:-preview} exited non-zero"; }
  grep -q 'Nothing to do' "$tmp/2.log" || bad "re-run ${mode:-preview} did not report nothing to do"
  grep -qx '  AGENTS.md' "$tmp/2.log" || bad "re-run ${mode:-preview} did not keep its own local AGENTS.md"
  [ "$(snapshot "$t1")" = "$before" ] || bad "re-run ${mode:-preview} changed the target"
done

# --- case 3: collisions ------------------------------------------------------

echo "case 3: tracked and differing destinations stop the run with zero writes"
t3="$tmp/tracked"
new_repo "$t3"
mkdir -p "$t3/.claude/commands"
printf '# the team review\n' >"$t3/.claude/commands/review.md"
"${G[@]}" -C "$t3" add -A
"${G[@]}" -C "$t3" commit -qm "team command"
refused "tracked command" "$tmp/3a" "tracked by this repository: .claude/commands/review.md" "$t3" "$t3" --local

t3b="$tmp/tracked-bank"
new_repo "$t3b"
mkdir -p "$t3b/memory-bank/context"
printf 'team notes\n' >"$t3b/memory-bank/context/notes.md"
"${G[@]}" -C "$t3b" add -A
"${G[@]}" -C "$t3b" commit -qm "team bank"
refused "tracked bank" "$tmp/3b" "already tracks .serel-memory.json or files under memory-bank/" "$t3b" "$t3b" --local

t3c="$tmp/differs"
new_repo "$t3c"
mkdir -p "$t3c/hooks"
printf '#!/bin/sh\necho mine\n' >"$t3c/hooks/session-start.sh"
refused "differing untracked file" "$tmp/3c" "exists and differs from this checkout: hooks/session-start.sh" "$t3c" "$t3c" --local

t3d="$tmp/bank-extra"
new_repo "$t3d"
mkdir -p "$t3d/memory-bank"
printf 'my notes\n' >"$t3d/memory-bank/notes.md"
refused "unknown bank file" "$tmp/3d" "memory-bank/ already holds memory-bank/notes.md" "$t3d" "$t3d" --local

# --- case 4: existing instructions -------------------------------------------

echo "case 4: existing AGENTS.md and CLAUDE.md stay intact"
t4="$tmp/instructions"
new_repo "$t4"
printf '# Team instructions\n' >"$t4/AGENTS.md"
printf '@AGENTS.md\n\nTeam Claude notes.\n' >"$t4/CLAUDE.md"
"${G[@]}" -C "$t4" add -A
"${G[@]}" -C "$t4" commit -qm "team instructions"
cp "$t4/AGENTS.md" "$tmp/agents.orig"
cp "$t4/CLAUDE.md" "$tmp/claude.orig"
state="$(git_state "$t4")"
bash "$INSTALL" "$t4" --local --apply >"$tmp/4.log" 2>&1 || { cat "$tmp/4.log"; bad "install beside existing instructions failed"; }
cmp -s "$t4/AGENTS.md" "$tmp/agents.orig" || bad "AGENTS.md changed"
cmp -s "$t4/CLAUDE.md" "$tmp/claude.orig" || bad "CLAUDE.md changed"
if grep -qxF /AGENTS.md "$t4/.git/info/exclude"; then bad "a team AGENTS.md was excluded"; fi
grep -qF 'Not installed: AGENTS.md' "$tmp/4.log" || bad "the run did not say AGENTS.md was left alone"
grep -qF "/start (Claude Code) or \$start (Codex)" "$tmp/4.log" || bad "the run did not name the explicit entry points"
[ "$(git_state "$t4")" = "$state" ] || bad "install beside team instructions changed git state"

t4b="$tmp/own-agents"
new_repo "$t4b"
printf '# My untracked notes\n' >"$t4b/AGENTS.md"
bash "$INSTALL" "$t4b" --local --apply >"$tmp/4b.log" 2>&1 || bad "install beside an untracked AGENTS.md failed"
git -C "$t4b" status --porcelain | grep -qx '?? AGENTS.md' || bad "an untracked user AGENTS.md was hidden"

# --- case 5: ignore negations ------------------------------------------------

echo "case 5: an ignore negation is refused"
t5="$tmp/negation"
new_repo "$t5"
printf '!.rules\n' >"$t5/.gitignore"
"${G[@]}" -C "$t5" add .gitignore
"${G[@]}" -C "$t5" commit -qm "re-include .rules"
refused ".gitignore negation" "$tmp/5a" "keeps this path visible to Git: .gitignore:1:!.rules" "$t5" "$t5" --local

t5b="$tmp/negation-exclude"
new_repo "$t5b"
printf '!/bin/serel-memory\n' >>"$t5b/.git/info/exclude"
refused "info/exclude negation" "$tmp/5b" "!/bin/serel-memory" "$t5b" "$t5b" --local

# Each bank template would be ignored, but the folder would not: a later
# memory-bank/archive/ file would show. The folder itself must be ignored.
t5c="$tmp/negation-bank-folder"
new_repo "$t5c"
printf '!/memory-bank/\n/memory-bank/*.md\n' >"$t5c/.gitignore"
"${G[@]}" -C "$t5c" add .gitignore
"${G[@]}" -C "$t5c" commit -qm "re-include the bank folder"
refused "bank folder negation" "$tmp/5c" "keeps the memory-bank/ folder visible to Git" "$t5c" "$t5c" --local

# A re-inclusion only the created folder reveals: the post-write check on the
# folder itself stops the run and rolls it back.
t5d="$tmp/negation-bank-subfolder"
new_repo "$t5d"
printf '!/memory-bank/\n/memory-bank/*\n!/memory-bank/archive/\n' >"$t5d/.gitignore"
"${G[@]}" -C "$t5d" add .gitignore
"${G[@]}" -C "$t5d" commit -qm "re-include a bank subfolder"
before="$(snapshot "$t5d")"
if bash "$INSTALL" "$t5d" --local --apply >"$tmp/5d.log" 2>&1; then
  bad "bank subfolder negation: apply succeeded (expected a rollback)"
fi
grep -qF "memory-bank is not ignored after writing the exclusions" "$tmp/5d.log" || { cat "$tmp/5d.log"; bad "bank subfolder negation: the folder check did not fire"; }
grep -q 'undoing this run' "$tmp/5d.log" || bad "bank subfolder negation: no rollback was reported"
[ "$(snapshot "$t5d")" = "$before" ] || bad "bank subfolder negation: rollback left changes"

# --- case 6: linked worktree -------------------------------------------------

echo "case 6: a linked worktree shares exclusions, not files"
t6="$tmp/main"
new_repo "$t6"
wt="$tmp/linked"
git -C "$t6" worktree add -q -b linked "$wt"
gitfile="$(cat "$wt/.git")"
main_state="$(git_state "$t6")"
wt_state="$(git_state "$wt")"
bash "$INSTALL" "$wt" --local --apply >"$tmp/6.log" 2>&1 || { cat "$tmp/6.log"; bad "install into a linked worktree failed"; }
if [ ! -f "$wt/.git" ] || [ "$(cat "$wt/.git")" != "$gitfile" ]; then bad "the worktree's .git file changed"; fi
grep -qxF /memory-bank/ "$t6/.git/info/exclude" || bad "exclusions did not reach the shared info/exclude"
grep -qF "Exclude: $t6/.git/info/exclude" "$tmp/6.log" || bad "the run did not name the shared exclude file"
[ -f "$wt/memory-bank/activeContext.md" ] || bad "the bank was not installed in the worktree"
[ ! -e "$t6/memory-bank" ] || bad "the bank leaked into the main worktree"
[ "$(git_state "$wt")" = "$wt_state" ] || bad "the install changed the worktree's git state"
[ "$(git_state "$t6")" = "$main_state" ] || bad "the install changed the main worktree's git state"
bash "$INSTALL" "$t6" --local --apply >"$tmp/6b.log" 2>&1 || { cat "$tmp/6b.log"; bad "a second install in the main worktree failed"; }
[ "$(grep -cxF /memory-bank/ "$t6/.git/info/exclude")" = 1 ] || bad "the second install duplicated exclude lines"
[ -f "$t6/memory-bank/activeContext.md" ] || bad "the main worktree did not get its own bank"

# --- case 7: source and target safety ----------------------------------------

echo "case 7: source/target safety"
if bash "$INSTALL" "$src" --local >"$tmp/7.log" 2>&1; then bad "the source checkout was accepted as a target"; fi
if bash "$INSTALL" "$t1/src" --local >"$tmp/7.log" 2>&1; then bad "a subdirectory was accepted as a target"; fi
grep -q 'repository root' "$tmp/7.log" || bad "a subdirectory target was not explained"
if bash "$INSTALL" "$t1" >"$tmp/7.log" 2>&1; then bad "a run without --local was accepted"; fi
mkdir "$src/nested-target"
"${G[@]}" init -q "$src/nested-target"
if bash "$INSTALL" "$src/nested-target" --local >"$tmp/7.log" 2>&1; then bad "a target inside the source was accepted"; fi
rm -rf "$src/nested-target"
t7="$tmp/holder"
new_repo "$t7"
mkdir "$t7/vendor"
cp -R "$src" "$t7/vendor/serel-memory"
before="$(snapshot "$t7")"
if bash "$t7/vendor/serel-memory/install.sh" "$t7" --local --apply >"$tmp/7.log" 2>&1; then
  bad "a source inside the target was accepted"
fi
[ "$(snapshot "$t7")" = "$before" ] || bad "a nested source wrote to the target"
mkdir "$tmp/copy"
(cd "$src" && tar -cf - --exclude .git .) | tar -xf - -C "$tmp/copy"
if bash "$tmp/copy/install.sh" "$t1" --local >"$tmp/7.log" 2>&1; then bad "a copy that is not a checkout was accepted"; fi
grep -q 'git checkout' "$tmp/7.log" || bad "a non-checkout source was not explained"

t7b="$tmp/symlinked"
new_repo "$t7b"
mkdir "$tmp/elsewhere"
ln -s "$tmp/elsewhere" "$t7b/.claude"
refused "symlinked .claude" "$tmp/7b" "UNSAFE PATH: .claude is a symlink" "$t7b" "$t7b" --local
[ -z "$(ls -A "$tmp/elsewhere")" ] || bad "the install wrote through a symlink"

t7c="$tmp/exclude-link"
new_repo "$t7c"
mv "$t7c/.git/info/exclude" "$tmp/real-exclude"
ln -s "$tmp/real-exclude" "$t7c/.git/info/exclude"
refused "symlinked exclude" "$tmp/7c" "is a symlink or not a regular file" "$t7c" "$t7c" --local

t7d="$tmp/exclude-hardlink"
new_repo "$t7d"
ln "$t7d/.git/info/exclude" "$tmp/hard-exclude"
refused "hard-linked exclude" "$tmp/7d" "has multiple hard links" "$t7d" "$t7d" --local

t7e="$tmp/nested-repo"
new_repo "$t7e"
"${G[@]}" init -q "$t7e/hooks"
refused "nested repository" "$tmp/7e" "hooks is a separate git repository" "$t7e" "$t7e" --local

# --- case 8: rollback --------------------------------------------------------

echo "case 8: an ordinary failure rolls back files and exclusions"
real_cp="$(command -v cp)"
mkdir "$tmp/shim"
cat >"$tmp/shim/cp" <<'SHIM_END'
#!/usr/bin/env bash
# Fails the one copy whose destination is $FAIL_DEST.
if [ "${!#}" = "$FAIL_DEST" ]; then echo "simulated copy failure" >&2; exit 1; fi
exec "$REAL_CP" "$@"
SHIM_END
chmod +x "$tmp/shim/cp"

mkdir "$tmp/empty-template"
for variant in with-info without-info; do
  t8="$tmp/rollback-$variant"
  if [ "$variant" = with-info ]; then
    new_repo "$t8"
    printf '# a line the user wrote\n/scratch/' >>"$t8/.git/info/exclude"
  else
    new_repo "$t8" --template="$tmp/empty-template"
    [ ! -e "$t8/.git/info" ] || { bad "fixture invalid: $variant has info/"; continue; }
  fi
  before="$(snapshot "$t8")"
  if PATH="$tmp/shim:$PATH" REAL_CP="$real_cp" FAIL_DEST="$t8/docs/serel-setup.md" \
    bash "$INSTALL" "$t8" --local --apply >"$tmp/8.log" 2>&1; then
    bad "$variant: a failed copy exited 0"
  fi
  grep -q 'simulated copy failure' "$tmp/8.log" || { cat "$tmp/8.log"; bad "$variant: the simulated failure did not happen"; }
  grep -q 'undoing this run' "$tmp/8.log" || bad "$variant: no rollback was reported"
  [ "$(snapshot "$t8")" = "$before" ] || bad "$variant: rollback left changes (files or exclusions)"
done

# --- case 9: provenance ------------------------------------------------------

echo "case 9: provenance is recorded honestly"
printf '\nA local edit.\n' >>"$src/docs/serel-setup.md"
t9="$tmp/dirty-source"
new_repo "$t9"
bash "$INSTALL" "$t9" --local --apply >"$tmp/9.log" 2>&1 || { cat "$tmp/9.log"; bad "install from a dirty source failed"; }
head_sha="$(git -C "$src" rev-parse HEAD)"
grep -qxF "{ \"upstream\": \"madeordinary/serel-memory\", \"ref\": \"$head_sha\", \"linked\": true }" "$t9/.serel-memory.json" ||
  bad "a dirty source was not recorded as linked to its commit: $(cat "$t9/.serel-memory.json")"
grep -q 'uncommitted payload changes' "$tmp/9.log" || bad "a dirty source was not warned about"
git -C "$src" checkout -q -- docs/serel-setup.md

"${G[@]}" -C "$src" commit -q --allow-empty -m "untagged"
t9b="$tmp/untagged-source"
new_repo "$t9b"
bash "$INSTALL" "$t9b" --local --apply >"$tmp/9b.log" 2>&1 || { cat "$tmp/9b.log"; bad "install from an untagged source failed"; }
head_sha="$(git -C "$src" rev-parse HEAD)"
grep -qxF "{ \"upstream\": \"madeordinary/serel-memory\", \"ref\": \"$head_sha\", \"linked\": false }" "$t9b/.serel-memory.json" ||
  bad "a clean untagged source was not recorded by its SHA: $(cat "$t9b/.serel-memory.json")"

# A tag Git accepts but the anchor must not interpolate: a quote would break
# the JSON. Anything that is not release-shaped falls back to the SHA.
"${G[@]}" -C "$src" tag 'v1"bad'
t9c="$tmp/odd-tag-source"
new_repo "$t9c"
bash "$INSTALL" "$t9c" --local --apply >"$tmp/9c.log" 2>&1 || { cat "$tmp/9c.log"; bad "install from an oddly tagged source failed"; }
grep -qxF "{ \"upstream\": \"madeordinary/serel-memory\", \"ref\": \"$head_sha\", \"linked\": false }" "$t9c/.serel-memory.json" ||
  bad "a tag that is not release-shaped was written into the anchor: $(cat "$t9c/.serel-memory.json")"
if command -v jq >/dev/null 2>&1; then
  jq -e '.ref | type == "string"' "$t9c/.serel-memory.json" >/dev/null || bad "the anchor is not valid JSON"
fi
git -C "$src" tag -d 'v1"bad' >/dev/null

# --- case 10: names that differ only in case ---------------------------------

echo "case 10: case-only name matches are refused"
# Tracked aliases are refused on every filesystem: a regular file, a directory
# on the way (a file and a submodule), the bank, and the anchor.
t10a="$tmp/case-rules"
new_repo "$t10a"
cp "$src/.rules" "$t10a/.RULES"
"${G[@]}" -C "$t10a" add .RULES
"${G[@]}" -C "$t10a" commit -qm "tracked .RULES with the template bytes"
refused "tracked .RULES" "$tmp/10a" ".rules matches the tracked path .RULES when case is ignored" "$t10a" "$t10a" --local

t10b="$tmp/case-hooks-file"
new_repo "$t10b"
printf 'a file, not a folder\n' >"$t10b/Hooks"
"${G[@]}" -C "$t10b" add Hooks
"${G[@]}" -C "$t10b" commit -qm "tracked Hooks file"
refused "tracked Hooks file" "$tmp/10b" "hooks matches the tracked path Hooks when case is ignored" "$t10b" "$t10b" --local

t10c="$tmp/case-bin-gitlink"
new_repo "$t10c"
"${G[@]}" -C "$t10c" update-index --add --cacheinfo "160000,$(git -C "$t10c" rev-parse HEAD),Bin"
"${G[@]}" -C "$t10c" commit -qm "tracked Bin submodule"
refused "tracked Bin gitlink" "$tmp/10c" "bin matches the tracked path Bin when case is ignored" "$t10c" "$t10c" --local

t10d="$tmp/case-bank"
new_repo "$t10d"
mkdir "$t10d/Memory-Bank"
printf 'team notes\n' >"$t10d/Memory-Bank/notes.md"
"${G[@]}" -C "$t10d" add Memory-Bank
"${G[@]}" -C "$t10d" commit -qm "tracked Memory-Bank"
refused "tracked Memory-Bank" "$tmp/10d" "already tracks .serel-memory.json or files under memory-bank/ (Memory-Bank/notes.md" "$t10d" "$t10d" --local

t10e="$tmp/case-anchor"
new_repo "$t10e"
printf '{}\n' >"$t10e/.Serel-Memory.json"
"${G[@]}" -C "$t10e" add .Serel-Memory.json
"${G[@]}" -C "$t10e" commit -qm "tracked anchor alias"
refused "tracked anchor alias" "$tmp/10e" "(.Serel-Memory.json, compared without case)" "$t10e" "$t10e" --local

# A tracked agents.md is existing instructions: skipped, never replaced or hidden.
t10f="$tmp/case-agents"
new_repo "$t10f"
printf '# Team instructions, lower case\n' >"$t10f/agents.md"
"${G[@]}" -C "$t10f" add agents.md
"${G[@]}" -C "$t10f" commit -qm "tracked agents.md"
cp "$t10f/agents.md" "$tmp/agents-lower.orig"
bash "$INSTALL" "$t10f" --local --apply >"$tmp/10f.log" 2>&1 || { cat "$tmp/10f.log"; bad "install beside a tracked agents.md failed"; }
grep -qF 'Not installed: AGENTS.md' "$tmp/10f.log" || bad "a tracked agents.md did not count as existing instructions"
cmp -s "$t10f/agents.md" "$tmp/agents-lower.orig" || bad "a tracked agents.md changed"
if grep -qixF /AGENTS.md "$t10f/.git/info/exclude"; then bad "a tracked agents.md was excluded"; fi
[ -z "$(git -C "$t10f" status --porcelain)" ] || bad "install beside a tracked agents.md changed git status"

# Untracked names stored with other capitalization only alias on a
# case-insensitive filesystem. core.ignorecase=false is the hard case: Git's
# exclude lines then match only the exact spelling the installer asked for.
probe="$tmp/CaseProbe"
: >"$probe"
if [ -e "$tmp/caseprobe" ]; then
  n=0
  for alias in .Claude/commands/mine.md Memory-Bank/ .Serel-Memory.json; do
    n=$((n + 1))
    t10g="$tmp/case-untracked-$n"
    new_repo "$t10g"
    git -C "$t10g" config core.ignorecase false
    case "$alias" in
      */) mkdir "$t10g/$alias" ;;
      */*) mkdir -p "$t10g/${alias%/*}"; printf 'mine\n' >"$t10g/$alias" ;;
      *) cp "$src/.rules" "$t10g/$alias" ;;
    esac
    want="${alias%%/*}"
    lower="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
    refused "untracked $want" "$tmp/10g-$n" "$lower already exists as $want, which differs only in case" "$t10g" "$t10g" --local
  done

  t10h="$tmp/case-untracked-agents"
  new_repo "$t10h"
  printf '# My notes, lower case\n' >"$t10h/agents.md"
  bash "$INSTALL" "$t10h" --local --apply >"$tmp/10h.log" 2>&1 || { cat "$tmp/10h.log"; bad "install beside an untracked agents.md failed"; }
  grep -qF 'Not installed: AGENTS.md' "$tmp/10h.log" || bad "an untracked agents.md did not count as existing instructions"
  git -C "$t10h" status --porcelain | grep -qx '?? agents.md' || bad "an untracked agents.md was hidden"
else
  echo "  (case-sensitive filesystem: untracked aliasing cases skipped)"
fi

if [ "$fail" -eq 0 ]; then
  echo "install smoke OK: preview is read-only, apply is hidden and idempotent, collisions and negations refuse, case-only matches refuse, worktrees share exclusions, rollback is complete, provenance is honest"
fi
exit "$fail"
