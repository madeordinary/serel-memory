#!/usr/bin/env bash
# Mechanics of tests/prepare-memory-use-fixture.sh, the builder behind the
# manual memory-use exercise. It cannot judge an agent's plan or review; it
# proves the exercise's inputs are what the guide says: paired builds differ
# only by the target lesson line, with identical history metadata and review
# diff; nothing in a workspace names its variant; the update-memory session
# starts from the control bank with only product code changed; unsafe targets
# are refused before anything is created; the checkout is left as it was.
# shellcheck disable=SC2015  # ok/bad never fail (plain either/or)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
B="$ROOT/tests/prepare-memory-use-fixture.sh"

command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 is required for this test"; exit 1; }
tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Fallible results are captured in standalone assignments before any comparison,
# so a failed command stops here with its exit status instead of comparing as
# an empty string (set -e does not cover substitutions inside [ ... ]).
die() { echo "FAIL $1"; exit 1; }
build() { bash "$B" "$@" >"$tmp/build.log" 2>&1 || { cat "$tmp/build.log"; bad "build $*"; }; }
meta() { git -C "$1" log --all --format='%s|%an|%ae|%ad|%cd'; }

before="$(git status --porcelain --untracked-files=all)" || die "git status failed in the checkout (exit $?)"

for mode in breakdown review; do
  build "$tmp/$mode-a" "$mode" with-lesson
  build "$tmp/$mode-b" "$mode" without-lesson
  a="$tmp/$mode-a"; b="$tmp/$mode-b"
  differ="$(diff -rq -x .git "$a" "$b")" || [ "$?" -eq 1 ] || die "$mode: diff -rq failed"
  [ "$differ" = "Files $a/.rules and $b/.rules differ" ] && ok "$mode: only .rules differs" || bad "$mode: pair differs beyond .rules: $differ"
  # diff exits 1 when files differ and 2 on trouble; only 0 and 1 are results.
  delta="$(diff "$a/.rules" "$b/.rules")" || [ "$?" -eq 1 ] || die "$mode: diff .rules failed"
  removed="$(grep -c '^<' <<<"$delta" || true)"
  added="$(grep -c '^>' <<<"$delta" || true)"
  [ "$removed" = 1 ] && [ "$added" = 0 ] && ok "$mode: control omits exactly one line" || bad "$mode: .rules delta is -$removed +$added"
  grep -q "^< .*line break" <<<"$delta" && ok "$mode: the omitted line is the target lesson" || bad "$mode: omitted line is not the target lesson"
  meta_a="$(meta "$a")" || die "$mode: git log failed in $a (exit $?)"
  meta_b="$(meta "$b")" || die "$mode: git log failed in $b (exit $?)"
  [ "$meta_a" = "$meta_b" ] && ok "$mode: identical history metadata" || bad "$mode: history metadata differs"
  # grep exits 1 when nothing matches and 2 on trouble.
  hits="$(grep -rIl -e with-lesson -e without-lesson --exclude-dir=.git "$a" "$b")" || [ "$?" -eq 1 ] || die "$mode: variant scan failed"
  [ -z "$hits" ] && ok "$mode: no workspace names its variant" || bad "$mode: variant named in $hits"
done

branch="$(git -C "$tmp/review-a" rev-parse --abbrev-ref HEAD)" || die "review: rev-parse failed (exit $?)"
[ "$branch" = notes-export ] && ok "review: candidate branch checked out" || bad "review: wrong branch $branch"
diff_a="$(git -C "$tmp/review-a" diff main...HEAD)" || die "review: git diff failed in review-a (exit $?)"
diff_b="$(git -C "$tmp/review-b" diff main...HEAD)" || die "review: git diff failed in review-b (exit $?)"
[ -n "$diff_a" ] && [ "$diff_a" = "$diff_b" ] && ok "review: identical diff under review" || bad "review: diffs differ or are empty"
status="$(git -C "$tmp/breakdown-a" status --porcelain)" || die "breakdown: git status failed (exit $?)"
[ -z "$status" ] && ok "breakdown: clean main" || bad "breakdown: dirty tree"

build "$tmp/session" update-memory
head_session="$(git -C "$tmp/session" rev-parse HEAD)" || die "update-memory: rev-parse failed (exit $?)"
head_control="$(git -C "$tmp/breakdown-b" rev-parse HEAD)" || die "breakdown: rev-parse failed (exit $?)"
[ "$head_session" = "$head_control" ] \
  && ok "update-memory: committed state is the control build" || bad "update-memory: history differs from the control build"
status="$(git -C "$tmp/session" status --porcelain --untracked-files=all)" || die "update-memory: git status failed (exit $?)"
[ "$status" = "$(printf ' M board.py\n M tests/test_board.py')" ] \
  && ok "update-memory: only product code changed, uncommitted" || bad "update-memory: status $(tr '\n' '|' <<<"$status")"

refused() { # <label> <target> <args...>
  local label="$1" t="$2"; shift 2
  if bash "$B" "$t" "$@" >/dev/null 2>&1; then bad "accepted $label"; else ok "refused $label"; fi
}
mkdir "$tmp/exists"
refused "an existing directory" "$tmp/exists" breakdown
ln -s "$tmp/nowhere" "$tmp/link"
refused "a symlink" "$tmp/link" breakdown
[ ! -e "$tmp/nowhere" ] && ok "symlink target left uncreated" || bad "created the symlink's target"
# An owned synthetic repository stands in for any Git work tree, this checkout
# included, so no contributor path is ever created or removed.
git init -q "$tmp/host"
refused "a target inside a Git work tree" "$tmp/host/fixture" breakdown
[ ! -e "$tmp/host/fixture" ] && ok "nothing created in the work tree" || bad "created a fixture inside a Git work tree"
refused "an unknown mode" "$tmp/x1" analyze
refused "a variant for update-memory" "$tmp/x2" update-memory without-lesson
[ ! -e "$tmp/x1" ] && [ ! -e "$tmp/x2" ] && ok "refusals create nothing" || bad "a refusal created its target"

after="$(git status --porcelain --untracked-files=all)" || die "git status failed in the checkout (exit $?)"
[ "$after" = "$before" ] && ok "checkout unchanged" || bad "the builder changed the checkout"

if [ "$fail" -eq 0 ]; then echo "memory-use fixture OK"; fi
exit "$fail"
