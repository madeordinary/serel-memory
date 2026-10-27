#!/usr/bin/env bash
# Mechanics of tests/prepare-overlap-fixture.sh, the builder behind the manual
# exercise in tests/workflow-overlap-acceptance.md. It cannot judge an agent's
# setup plan or sync review; it proves the exercise's inputs are what the
# guide says: Serel Memory is installed only in the cases that say so, with
# framework files identical to this checkout; each case holds exactly its own
# workflows, each laid out as Serel Memory lays out its own (a source with its
# manifest and a byte-identical Claude copy, no Claude commands); no Kit file
# is present; only the intended edits are uncommitted; the upgrade case's
# upstream adds exactly one workflow over the installed baseline; nothing in a
# workspace names its case or the expected results; unsafe targets are refused
# before anything is created; the checkout is left as it was.
# shellcheck disable=SC2015  # ok/bad never fail (plain either/or)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
B="$ROOT/tests/prepare-overlap-fixture.sh"
CASES="memory-new customized kit-writing kit-verify duplicated coexist unrecorded specialized upgrade"

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Fallible results are captured in standalone assignments before any
# comparison, so a failed command stops here instead of comparing as empty.
die() { echo "FAIL $1"; exit 1; }

before="$(git status --porcelain --untracked-files=all)" || die "git status failed in the checkout (exit $?)"

# The files a shared install has, as the builder copies them.
framework="$(
  { printf '%s\n' AGENTS.md docs/workflow-contract.md docs/cross-agent-review.md docs/serel-setup.md bin/serel-memory
    find .claude/skills .agents/skills hooks -type f; } | LC_ALL=C sort
)" || die "could not list the framework files"
# Each case's own workflows, by the name the source and its copy share.
own() {
  case "$1" in
    memory-new) echo "pick-up wrap-up" ;;
    customized) echo "start" ;;
    kit-writing) echo "announce tidy-text" ;;
    kit-verify) echo "check-by-hand" ;;
    duplicated) echo "resume-work save-session" ;;
    coexist|unrecorded) echo "resume-brief" ;;
    specialized) echo "start-season volunteer-handoff" ;;
    upgrade) echo "release-notes" ;;
  esac
}
sorted() { printf '%s\n' "$1" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'; }
same() { [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; }

for c in $CASES; do
  bash "$B" "$tmp/$c" "$c" >"$tmp/build.log" 2>&1 || { cat "$tmp/build.log"; die "build $c"; }
done

for c in $CASES; do
  w="$tmp/$c/project"
  case "$c" in kit-verify|duplicated|coexist|unrecorded|upgrade) installed=yes ;; *) installed=no ;; esac

  if [ "$installed" = yes ]; then
    differ=""
    while IFS= read -r f; do
      same "$ROOT/$f" "$w/$f" || differ="$differ $f"
    done <<<"$framework"
    [ -z "$differ" ] && ok "$c: framework files match this checkout" || bad "$c: framework files differ or are missing:$differ"
    anchor="$(git -C "$w" ls-files -- .serel-memory.json)" || die "$c: git ls-files failed (exit $?)"
    [ "$anchor" = .serel-memory.json ] && ok "$c: tracked anchor (shared install)" || bad "$c: anchor missing or untracked"
    blank=""
    for f in projectbrief productContext systemPatterns techContext decisionLog activeContext progress; do
      if [ ! -s "$w/memory-bank/$f.md" ] || grep -q '<!--' "$w/memory-bank/$f.md"; then blank="$blank $f"; fi
    done
    [ -z "$blank" ] && ok "$c: initialized bank" || bad "$c: blank or missing bank files:$blank"
  else
    present=""
    for f in .serel-memory.json memory-bank .rules bin hooks docs/workflow-contract.md docs/serel-setup.md; do
      if [ -e "$w/$f" ] || [ -L "$w/$f" ]; then present="$present $f"; fi
    done
    [ -z "$present" ] && ok "$c: no Serel Memory installed" || bad "$c: Serel Memory files present:$present"
  fi

  # The case's own workflows: every source or Claude copy that is not this
  # checkout's own file, byte for byte.
  mine=""
  for f in "$w"/.agents/skills/*/SKILL.md "$w"/.claude/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    same "$ROOT/${f#"$w"/}" "$f" || mine="$mine $(basename "$(dirname "$f")")"
  done
  mine="$(sorted "$mine")"
  expected="$(sorted "$(own "$c")")"
  [ "$mine" = "$expected" ] && ok "$c: own workflows are $expected" || bad "$c: own workflows are '$mine', expected '$expected'"

  # Every workflow is discoverable by each CLI, in both directions: a source
  # with its manifest, and its byte-identical Claude copy alone in its folder.
  # The ask pair is the one exception, as in check-single-source.sh. No
  # workflow is a Claude command.
  unpaired=""
  for d in "$w"/.agents/skills/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    [ -f "$d/SKILL.md" ] && [ -f "$d/agents/openai.yaml" ] || unpaired="$unpaired $n:source-or-manifest"
    [ "$n" = ask-claude ] && continue
    same "$d/SKILL.md" "$w/.claude/skills/$n/SKILL.md" || unpaired="$unpaired $n:claude-copy"
    extra="$(find "$w/.claude/skills/$n" -mindepth 1 ! -name SKILL.md -print 2>/dev/null)" || true
    [ -z "$extra" ] || unpaired="$unpaired $n:extra-files"
  done
  for d in "$w"/.claude/skills/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    [ "$n" = ask-codex ] || [ -f "$w/.agents/skills/$n/SKILL.md" ] || unpaired="$unpaired $n:no-source"
  done
  [ ! -e "$w/.claude/commands" ] || unpaired="$unpaired .claude/commands"
  [ -z "$unpaired" ] && ok "$c: every workflow is a source with its manifest and a byte-identical Claude copy" || bad "$c: not laid out as one source:$unpaired"

  kit=""
  for f in .serel-kit.json .claude/commands/polish.md .claude/commands/verify-map.md \
    .claude/skills/polish .claude/skills/verify-map .agents/skills/polish .agents/skills/verify-map; do
    if [ -e "$w/$f" ]; then kit="$kit $f"; fi
  done
  [ -z "$kit" ] && ok "$c: no Serel Kit files" || bad "$c: Kit files present:$kit"

  status="$(git -C "$w" status --porcelain --untracked-files=all)" || die "$c: git status failed (exit $?)"
  if [ "$c" = duplicated ]; then
    [ "$status" = "$(printf ' M .agents/skills/save-session/SKILL.md\n M .claude/skills/save-session/SKILL.md')" ] \
      && ok "$c: only save-session's source and Claude copy are uncommitted" || bad "$c: status $(tr '\n' '|' <<<"$status")"
    numstat="$(git -C "$w" diff --numstat)" || die "$c: git diff failed (exit $?)"
    removed="$(awk '{ s += $2 } END { print s + 0 }' <<<"$numstat")"
    added="$(awk '{ s += $1 } END { print s + 0 }' <<<"$numstat")"
    [ "$removed" = 0 ] && [ "$added" -gt 0 ] \
      && ok "$c: the uncommitted edit only adds lines Git history lacks" || bad "$c: uncommitted edit is +$added -$removed"
  else
    [ -z "$status" ] && ok "$c: clean work tree" || bad "$c: dirty work tree: $(tr '\n' '|' <<<"$status")"
  fi

  # Nothing the builder wrote for the project names a case or the expected
  # results; copies of this checkout's framework files are skipped.
  hits=""
  files="$(find "$w" -path "$w/.git" -prune -o -type f -print)" || die "$c: find failed"
  while IFS= read -r f; do
    rel="${f#"$w"/}"
    if same "$ROOT/$rel" "$f"; then continue; fi
    for t in $CASES overlap duplicat; do
      if grep -qiF -- "$t" "$f"; then hits="$hits $rel:$t"; fi
    done
  done <<<"$files"
  log="$(git -C "$w" log --all --format='%s%n%b')" || die "$c: git log failed (exit $?)"
  refs="$(git -C "$w" for-each-ref --format='%(refname)')" || die "$c: git for-each-ref failed (exit $?)"
  for t in $CASES overlap duplicat; do
    if grep -qiF -- "$t" <<<"$log$refs"; then hits="$hits history:$t"; fi
  done
  [ -z "$hits" ] && ok "$c: nothing names a case or an expected result" || bad "$c: named in$hits"
done

# The recorded and unrecorded sessions differ only by their actual project
# decision. This prevents a "coexistence" case whose workflows are unrelated.
pair_diff="$(diff -rq -x .git "$tmp/coexist/project" "$tmp/unrecorded/project")" ||
  [ "$?" -eq 1 ] || die "could not compare the coexistence pair"
[ "$pair_diff" = "Files $tmp/coexist/project/docs/workflow.md and $tmp/unrecorded/project/docs/workflow.md differ" ] \
  && ok "coexistence pair differs only in the recorded project decision" \
  || bad "coexistence pair differs elsewhere: $pair_diff"

# Upgrade: a bare synthetic upstream whose main adds one workflow (source,
# manifest and Claude copy) over the baseline the workspace installed, and
# nothing fetched yet.
w="$tmp/upgrade/project"
up="$tmp/upgrade/upstream.git"
bare="$(git -C "$up" rev-parse --is-bare-repository)" || die "upgrade: no upstream repository (exit $?)"
[ "$bare" = true ] && ok "upgrade: upstream is a bare repository beside the workspace" || bad "upgrade: upstream is not bare"
url="$(git -C "$w" remote get-url upstream)" || die "upgrade: no upstream remote (exit $?)"
[ "$url" = "$up" ] && ok "upgrade: the upstream remote is the local path" || bad "upgrade: upstream remote is $url"
ref="$(sed -n 's/.*"ref":"\([^"]*\)".*/\1/p' "$w/.serel-memory.json")"
git -C "$up" rev-parse --verify --quiet "refs/tags/$ref^{commit}" >/dev/null \
  && ok "upgrade: the anchor's ref is an upstream tag" || bad "upgrade: anchor ref '$ref' is not an upstream tag"
added="$(git -C "$up" diff --name-status "refs/tags/$ref" main)" || die "upgrade: git diff failed in upstream (exit $?)"
[ "$added" = "$(printf 'A\t.agents/skills/changelog/SKILL.md\nA\t.agents/skills/changelog/agents/openai.yaml\nA\t.claude/skills/changelog/SKILL.md')" ] \
  && ok "upgrade: upstream main adds exactly one workflow" || bad "upgrade: upstream change is $(tr '\n' '|' <<<"$added")"
baseline="$(git -C "$up" ls-tree -r --name-only "refs/tags/$ref")" || die "upgrade: git ls-tree failed (exit $?)"
[ "$baseline" = "$framework" ] && ok "upgrade: the baseline is this checkout's framework" || bad "upgrade: the baseline file list differs from the framework"
differ=""
while IFS= read -r f; do
  git -C "$up" show "refs/tags/$ref:$f" | cmp -s - "$w/$f" || differ="$differ $f"
done <<<"$baseline"
[ -z "$differ" ] && ok "upgrade: the workspace holds the baseline unchanged" || bad "upgrade: the workspace differs from the baseline:$differ"
[ ! -e "$w/.claude/skills/changelog" ] && [ ! -e "$w/.agents/skills/changelog" ] \
  && ok "upgrade: the new workflow is not in the workspace yet" || bad "upgrade: the new workflow is already installed"
head_up="$(git -C "$up" rev-parse main)" || die "upgrade: rev-parse failed in upstream (exit $?)"
if git -C "$w" cat-file -e "$head_up^{commit}" 2>/dev/null; then bad "upgrade: upstream was already fetched"; else ok "upgrade: nothing fetched yet"; fi
[ ! -e "$tmp/upgrade/stage" ] && ok "upgrade: no staging repository left behind" || bad "upgrade: staging repository left behind"
for c in $CASES; do
  [ "$c" = upgrade ] && continue
  [ ! -e "$tmp/$c/upstream.git" ] || bad "$c: has an upstream repository"
done

refused() { # <label> <target> <args...>
  local label="$1" t="$2"; shift 2
  if bash "$B" "$t" "$@" >/dev/null 2>&1; then bad "accepted $label"; else ok "refused $label"; fi
}
mkdir "$tmp/empty"
refused "an existing empty directory" "$tmp/empty" memory-new
mkdir "$tmp/full"
printf 'keep\n' >"$tmp/full/keep.txt"
refused "an existing nonempty directory" "$tmp/full" memory-new
left_empty="$(find "$tmp/empty" -mindepth 1 -print)" || die "find failed"
left_full="$(find "$tmp/full" -mindepth 1 -print)" || die "find failed"
[ -z "$left_empty" ] && [ "$left_full" = "$tmp/full/keep.txt" ] \
  && ok "existing directories left as they were" || bad "a refusal wrote into an existing directory"
ln -s "$tmp/nowhere" "$tmp/link"
refused "a symlink" "$tmp/link" memory-new
[ ! -e "$tmp/nowhere" ] && ok "symlink target left uncreated" || bad "created the symlink's target"
# An owned synthetic repository stands in for any Git work tree, this checkout
# included, so no contributor path is ever created or removed.
git init -q "$tmp/host"
refused "a target inside a Git work tree" "$tmp/host/fixture" memory-new
[ ! -e "$tmp/host/fixture" ] && ok "nothing created in the work tree" || bad "created a fixture inside a Git work tree"
refused "a missing parent directory" "$tmp/no-such-parent/fixture" memory-new
refused "an unknown case" "$tmp/x1" nonsense
refused "a missing case" "$tmp/x2"
refused "an extra argument" "$tmp/x3" memory-new extra
[ ! -e "$tmp/no-such-parent" ] && [ ! -e "$tmp/x1" ] && [ ! -e "$tmp/x2" ] && [ ! -e "$tmp/x3" ] \
  && ok "refusals create nothing" || bad "a refusal created its target"

after="$(git status --porcelain --untracked-files=all)" || die "git status failed in the checkout (exit $?)"
[ "$after" = "$before" ] && ok "checkout unchanged" || bad "the builder changed the checkout"

if [ "$fail" -eq 0 ]; then echo "overlap fixture OK"; fi
exit "$fail"
