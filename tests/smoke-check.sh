#!/usr/bin/env bash
# Drift checker contract test — bin/serel-memory check.
#
# Builds synthetic fixture repos (never this repo's own bank) and drives every
# finding kind and every check the contract documents: anchor, bank, retention,
# evidence markers, unmarked bullets, and the offline framework baseline.
# Assertions are exit codes and the summary counts — never a grep for a success
# string.
# shellcheck disable=SC2015,SC2016  # ok/bad never fail (plain either/or); backticks in fixture markdown are literal
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
CHECK="$ROOT/bin/serel-memory"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
GIT="git -c user.email=test@test -c user.name=smoke-check"

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required for this test (and for the checker)"; exit 1; }

# --- Runner and assertions ----------------------------------------------------
OUT=""; RC=0
run() {
  local rc=0
  OUT="$("$CHECK" check "$@" 2>&1)" || rc=$?
  RC="$rc"
}
summary() { printf '%s\n' "$OUT" | grep '^serel-memory check:' || true; }
sfield() { summary | awk -v w="$1," '{ for (i = 1; i <= NF; i++) if ($i == w) print $(i - 1) }'; }
baseline_field() { summary | awk '{ for (i = 1; i <= NF; i++) if ($i == "baseline:") print $(i + 1) }'; }

assert_rc() { # want label
  [ "$RC" = "$1" ] && ok "$2 — exit $1" || { bad "$2 — exit $RC, want $1"; printf '%s\n' "$OUT" | sed 's/^/       /'; }
}
assert_count() { # kind want label
  local got; got="$(sfield "$1")"
  [ "$got" = "$2" ] && ok "$3 — $2 $1" || { bad "$3 — $1=$got, want $2"; printf '%s\n' "$OUT" | sed 's/^/       /'; }
}
assert_has() { # pattern label
  printf '%s\n' "$OUT" | grep -q -- "$1" && ok "$2" || { bad "$2 — no line matching: $1"; printf '%s\n' "$OUT" | sed 's/^/       /'; }
}
assert_not() { # pattern label
  printf '%s\n' "$OUT" | grep -q -- "$1" && { bad "$2 — unexpected line matching: $1"; printf '%s\n' "$OUT" | sed 's/^/       /'; } || ok "$2"
}
assert_one_summary() { # label
  local n; n="$(summary | wc -l | tr -d ' ')"
  [ "$n" = "1" ] && ok "$1" || bad "$1 — $n summary lines"
}

# --- Fixture builders ---------------------------------------------------------
anchor() { printf '{ "upstream": "local/serel-memory", "ref": "%s", "linked": false }\n' "$2" > "$1/.serel-memory.json"; }

write_bank() { # bank_dir
  local b="$1"
  mkdir -p "$b"
  cat > "$b/projectbrief.md" <<'MD'
# Project Brief

## What

A widget renderer used by the drift-checker fixtures.

## Success looks like

- [ ] The widget renders
MD
  cat > "$b/productContext.md" <<'MD'
# Product Context

## The user

Someone who renders widgets on a schedule.
MD
  cat > "$b/systemPatterns.md" <<'MD'
# System Patterns

## Architecture

One renderer, one queue, no shared state.
MD
  cat > "$b/techContext.md" <<'MD'
# Tech Context

## Stack

- **Language**: Bash
- **Runtime / framework**: POSIX utilities
- **Database**: none

## Environment variables

- `WIDGET_HOME` — where widgets live
MD
  cat > "$b/decisionLog.md" <<'MD'
# Decision Log

## Active decisions

- **One queue** (2026-01-02) — two queues drifted; evidence: src/widget.js; result: shipped.
MD
  cat > "$b/activeContext.md" <<'MD'
# Active Context

## Current focus

Keeping the renderer honest.

## Recent changes

- Split the queue out of the renderer.
MD
  write_progress "$b" '- The renderer renders widgets'
}

write_progress() { # bank_dir works_bullets
  cat > "$1/progress.md" <<MD
# Progress

## Status

**Phase:** building

## What works

$2

## Recent milestones

- 2026-01-02 first widget rendered
MD
}

build_fixture() { # dir
  local d="$1"
  mkdir -p "$d/hooks/lib" "$d/bin" "$d/src" "$d/docs" "$d/.claude/commands" "$d/.agents/skills/demo"
  cp "$ROOT/hooks/lib/resolve-scope.sh" "$ROOT/hooks/lib/rotate-check.sh" "$d/hooks/lib/"
  cp "$CHECK" "$d/bin/serel-memory"
  echo "# Agents" > "$d/AGENTS.md"
  echo "# Claude" > "$d/CLAUDE.md"
  echo "# Workflow contract" > "$d/docs/workflow-contract.md"
  echo "# Cross-agent review" > "$d/docs/cross-agent-review.md"
  echo "# demo command" > "$d/.claude/commands/demo.md"
  echo "# demo skill" > "$d/.agents/skills/demo/SKILL.md"
  echo "widget v1" > "$d/src/widget.js"
  echo "gadget v1" > "$d/src/gadget.js"
  write_bank "$d/memory-bank"
  anchor "$d" "v1.0.0"
  (cd "$d" && $GIT init --quiet && $GIT add -A && $GIT commit --quiet -m "fixture")
}

# =============================================================================
# 1. Clean bank: nothing to report but the exit-neutral notes
# =============================================================================
F="$tmp/clean"
build_fixture "$F"
BASE="$(git -C "$F" rev-parse HEAD)"
echo "gadget v2" > "$F/src/gadget.js"
(cd "$F" && $GIT commit --quiet -am "change the gadget")

write_progress "$F/memory-bank" "- The renderer renders widgets (verified: $BASE src/widget.js)
- The queue drains (verified: $BASE src/widget.js docs/workflow-contract.md)
- Something nobody measured"

run --root "$F"
assert_rc 0 "clean fixture"
assert_count drift 0 "clean fixture"
assert_count stale 0 "clean fixture"
assert_count incomplete 0 "clean fixture"
assert_count warn 0 "clean fixture"
assert_count fresh 2 "clean fixture"
assert_count unmarked 2 "clean fixture"
assert_one_summary "clean fixture prints exactly one summary line"
[ "$(baseline_field)" = "unavailable" ] && ok "clean fixture — baseline: unavailable" || bad "baseline field is '$(baseline_field)'"
assert_has "^INFO repo no local baseline" "unresolvable anchor ref is INFO, not INCOMPLETE"
assert_has "^INFO memory-bank/progress.md 2 unmarked bullets in recognized sections" "unmarked bullets are counted and named"
assert_not "^DRIFT" "clean fixture reports no drift"

# The checker is read-only: the fixture must be untouched apart from our edits.
run --root "$F"
[ -z "$(git -C "$F" status --porcelain -- src docs hooks bin)" ] && ok "checker writes nothing outside the bank" || bad "checker dirtied the fixture"

# =============================================================================
# 2. Evidence markers
# =============================================================================
write_progress "$F/memory-bank" "- The gadget still gadgets (verified: $BASE src/gadget.js)"
run --root "$F"
assert_rc 1 "stale marker"
assert_count stale 1 "stale marker"
assert_count fresh 0 "stale marker"
assert_has "^STALE memory-bank/progress.md:9 declared evidence differs since $BASE: src/gadget.js" "stale marker names the sha and the changed path"
assert_not "verified as true" "wording never claims a bank line is true"

write_progress "$F/memory-bank" "- Half true (verified: $BASE src/widget.js src/gadget.js)"
run --root "$F"
assert_rc 1 "multi-path marker is stale when any path moved"
assert_count stale 1 "multi-path marker"

write_progress "$F/memory-bank" "- Unknown revision (verified: 0123456789abcdef0123456789abcdef01234567 src/widget.js)"
run --root "$F"
assert_rc 2 "unknown revision"
assert_count incomplete 1 "unknown revision"
assert_has "unknown revision 0123456789abcdef" "unknown revision is INCOMPLETE"

write_progress "$F/memory-bank" "- No evidence at all (verified: $BASE)"
run --root "$F"
assert_rc 2 "marker with no paths"
assert_has "marker names no evidence" "sha without a path is INCOMPLETE"

write_progress "$F/memory-bank" "- Points nowhere (verified: $BASE src/nope.js)"
run --root "$F"
assert_rc 2 "missing evidence path"
assert_has "evidence path missing at HEAD: src/nope.js" "path absent at HEAD is INCOMPLETE"

write_progress "$F/memory-bank" "- Dirty evidence (verified: $BASE src/widget.js)"
echo "widget edited" >> "$F/src/widget.js"
run --root "$F"
assert_rc 2 "dirty evidence"
assert_has "evidence dirty in worktree: src/widget.js" "uncommitted evidence is INCOMPLETE, not fresh"
git -C "$F" checkout -- src/widget.js

printf '# Progress\n\n## What works\n\n- Documented syntax, not a claim\n\n```text\nverified: %s src/gadget.js\n```\n' "$BASE" > "$F/memory-bank/progress.md"
run --root "$F"
assert_rc 0 "marker inside a fence is decorative"
assert_count stale 0 "fenced marker"
assert_count fresh 0 "fenced marker"
assert_count unmarked 1 "fenced marker"
assert_has "^INFO memory-bank/progress.md 1 unmarked bullet in recognized sections" "the unmarked note reads as English at n=1"

# A marker anywhere in the bank counts, not only in progress.md.
write_progress "$F/memory-bank" "- Nothing here"
printf '# Active Context\n\n## Current focus\n\nRendering (verified: %s src/widget.js).\n' "$BASE" > "$F/memory-bank/activeContext.md"
run --root "$F"
assert_rc 0 "marker in activeContext.md"
assert_count fresh 1 "marker in activeContext.md"

# =============================================================================
# 3. Retention (soft targets: WARN, exit-neutral)
# =============================================================================
{
  printf '# Progress\n\n## Status\n\n**Phase:** building\n\n## What works\n\n- Renders\n\n## Recent milestones\n\n'
  i=1
  while [ "$i" -le 13 ]; do printf -- '- 2026-01-%02d milestone %d\n' "$i" "$i"; i=$((i + 1)); done
} > "$F/memory-bank/progress.md"
run --root "$F"
assert_rc 0 "retention overage is exit-neutral"
assert_count warn 1 "retention overage"
assert_has "^WARN memory-bank/progress.md over the retention target: rotate-check says ROTATE 3" "retention WARN quotes the helper's RESULT"
write_progress "$F/memory-bank" "- Renders"

# =============================================================================
# 4. Bank shape: missing file, template-only, overlay
# =============================================================================
rm "$F/memory-bank/techContext.md"
run --root "$F"
assert_rc 1 "missing bank file"
assert_count drift 1 "missing bank file"
assert_has "^DRIFT memory-bank/techContext.md missing bank file" "a missing core file is DRIFT"
write_bank "$F/memory-bank"

T="$tmp/templates"
build_fixture "$T"
cp "$ROOT"/memory-bank/*.md "$T/memory-bank/"
run --root "$T"
assert_rc 1 "shipped templates are uninitialized"
assert_count drift 7 "shipped templates"
for f in projectbrief productContext systemPatterns techContext decisionLog activeContext progress; do
  assert_has "^DRIFT memory-bank/$f.md uninitialized" "template $f.md is flagged"
done

# Isolated classification fixtures: techContext.md carries ONE kind of line and
# nothing else, so a broken rule cannot hide behind neighbouring prose. The rest
# of the bank is initialized, so drift here is 0 or exactly 1.
write_bank "$T/memory-bank"
only_tech() { printf '%s\n' "$1" > "$T/memory-bank/techContext.md"; }

only_tech '# Tech Context

## Stack

- **Language**: Bash
- **Database**: Postgres'
run --root "$T"
assert_count drift 0 "populated label bullets, alone, are content"

only_tech '# Tech Context

## Stack

- **Language**: Rust [2024 edition]'
run --root "$T"
assert_count drift 0 "a bracketed aside in a real value is content"

only_tech '# Tech Context

## Notable dependencies

- [ADR-1] Adopt SQLite for durable storage.'
run --root "$T"
assert_count drift 0 "a bracketed label on a real sentence is content"

only_tech '# Tech Context

## Constraints (technical)

> Postgres 16 only; no other engine is supported.'
run --root "$T"
assert_count drift 0 "a blockquote after a section heading is content"

only_tech '# Tech Context

## Stack

- **Language**:
- **Database**:'
run --root "$T"
assert_count drift 1 "label bullets with no value are still template"

only_tech '# Tech Context

> The stack and what binds our choices.
> Update when dependencies change.

## Stack

-'
run --root "$T"
assert_count drift 1 "preamble guidance plus empty bullets is still template"
write_bank "$T/memory-bank"

rm -rf "$F/memory-bank/../memory-bank.local"
mkdir -p "$F/memory-bank.local"
cp "$F/memory-bank/activeContext.md" "$F/memory-bank/progress.md" "$F/memory-bank.local/"
run --root "$F"
assert_rc 0 "partial overlay"
assert_count drift 0 "partial overlay is not drift"
assert_has "^INFO memory-bank.local/projectbrief.md overlay lacks" "overlay gaps are INFO"
rm -rf "$F/memory-bank.local"

M="$tmp/nobank"
build_fixture "$M"
rm -rf "$M/memory-bank"
run --root "$M"
assert_rc 1 "bank directory missing"
assert_has "^DRIFT memory-bank bank directory missing" "an absent bank is one DRIFT, not seven"

# =============================================================================
# 5. Anchor
# =============================================================================
# The legacy v0.x anchor name is built here rather than written literally so
# tests/check-compatibility.sh keeps guarding that identifier everywhere.
legacy=".basecamp"
echo '{ "upstream": "x" }' > "$F/$legacy.json"
run --root "$F"
assert_rc 1 "legacy anchor"
assert_has "^DRIFT $legacy.json legacy anchor: migrate" "a legacy anchor beside the current one is DRIFT"
rm "$F/$legacy.json"

printf '{ "upstream": "x", broken\n' > "$F/.serel-memory.json"
run --root "$F"
assert_rc 2 "unparseable anchor"
assert_has "anchor does not parse as JSON" "a malformed anchor is INCOMPLETE"

printf '{ "upstream": "local/serel-memory", "ref": 4, "linked": "no" }\n' > "$F/.serel-memory.json"
run --root "$F"
assert_rc 2 "anchor key types"
assert_has 'anchor key "ref" must be a string (got number)' "wrong anchor key type is INCOMPLETE"
assert_has 'anchor key "linked" must be a boolean (got string)' "wrong anchor key type is INCOMPLETE"

rm "$F/.serel-memory.json"
run --root "$F"
assert_rc 2 "anchor missing"
assert_has "provenance anchor missing" "no anchor at all is INCOMPLETE"
anchor "$F" "v1.0.0"

# =============================================================================
# 6. jq and git preconditions
# =============================================================================
mkdir -p "$tmp/nojq"
for b in bash sh awk sed grep find sort cut git tr mktemp dirname basename cat printf wc head tail; do
  p="$(command -v "$b" 2>/dev/null || true)"; [ -n "$p" ] && ln -sf "$p" "$tmp/nojq/$b"
done
rc=0
nojq_out="$(PATH="$tmp/nojq" "$CHECK" check --root "$F" 2>&1)" || rc=$?
[ "$rc" = "2" ] && ok "no jq — exit 2" || bad "no jq — exit $rc, want 2"
printf '%s\n' "$nojq_out" | grep -q '^INCOMPLETE repo jq is required' && ok "no jq — one clear INCOMPLETE" || bad "no jq — message was: $nojq_out"
printf '%s\n' "$nojq_out" | grep -q '^serel-memory check: 0 drift, 0 stale, 1 incomplete' && ok "no jq — summary still printed" || bad "no jq — no summary line"

rc=0
"$CHECK" check --root "$tmp" >/dev/null 2>&1 || rc=$?
[ "$rc" = "2" ] && ok "non-repo root — exit 2" || bad "non-repo root — exit $rc, want 2"

# =============================================================================
# 7. Scoped banks: one bank per invocation, paths relative to the scope root
# =============================================================================
S="$tmp/scoped"
build_fixture "$S"
mkdir -p "$S/projects/widget/src"
write_bank "$S/projects/widget/memory-bank"
echo "project widget v1" > "$S/projects/widget/src/core.js"
printf '{ "upstream": "local/serel-memory", "ref": "v1.0.0", "linked": false, "scopes": ["projects"] }\n' > "$S/.serel-memory.json"
(cd "$S" && $GIT add -A && $GIT commit --quiet -m "scoped fixture")
SBASE="$(git -C "$S" rev-parse HEAD)"
write_progress "$S/projects/widget/memory-bank" "- Core works (verified: $SBASE src/core.js)"
write_progress "$S/memory-bank" "- Root portfolio state"

run --root "$S" --scope projects/widget
assert_rc 0 "--scope selects the project bank"
assert_count fresh 1 "--scope project bank — marker path resolved against the scope root"
assert_has "projects/widget/memory-bank/progress.md" "--scope reports the project bank's file"
assert_not "^INFO memory-bank/progress.md" "--scope reads only the selected bank"

rc=0
OUT="$(cd "$S/projects/widget" && "$CHECK" check --root "$S" 2>&1)" || rc=$?
RC="$rc"
assert_rc 0 "cwd inside a project resolves that project"
assert_has "projects/widget/memory-bank/progress.md" "cwd-resolved scope reports the project bank"

run --root "$S"
assert_rc 0 "root scope with scopes configured"
assert_has "^INFO memory-bank/progress.md" "root scope reads the root bank"

run --root "$S" --scope projects/nope
assert_rc 2 "unknown --scope"
assert_has "^INCOMPLETE repo scope not resolved" "an unknown selector is INCOMPLETE, never a guess"

printf '{ "upstream": "local/serel-memory", "ref": "v1.0.0", "linked": false, "scopes": "projects" }\n' > "$S/.serel-memory.json"
run --root "$S"
assert_rc 2 "degraded scopes config"
assert_has "^INCOMPLETE repo scopes: " "a resolver warning is INCOMPLETE"

# =============================================================================
# 8. Framework baseline (offline)
# =============================================================================
B="$tmp/baseline"
build_fixture "$B"
git -C "$B" update-ref refs/serel-memory/anchor HEAD
run --root "$B"
assert_rc 0 "baseline available and identical"
[ "$(baseline_field)" = "refs/serel-memory/anchor" ] && ok "baseline names the ref it compared" || bad "baseline field is '$(baseline_field)'"

echo "# Agents (customized)" > "$B/AGENTS.md"
rm "$B/docs/cross-agent-review.md"
echo "not a framework file" > "$B/src/widget.js"
run --root "$B"
assert_rc 1 "baseline with a missing framework file"
assert_count drift 1 "baseline drift"
assert_has "^DRIFT docs/cross-agent-review.md framework file missing" "a framework file gone missing is DRIFT"
assert_has "^INFO AGENTS.md differs from anchor baseline" "a customized framework file is INFO"
assert_not "^DRIFT src/widget.js" "baseline comparison is bounded to the framework allowlist"
assert_not "^INFO src/widget.js" "baseline comparison is bounded to the framework allowlist"

# =============================================================================
# 9. The documented shape of a real report: two fresh markers, one stale
# =============================================================================
write_bank "$F/memory-bank"
write_progress "$F/memory-bank" "- The renderer renders widgets (verified: $BASE src/widget.js)
- The docs describe it (verified: $BASE docs/workflow-contract.md)
- The gadget still gadgets (verified: $BASE src/gadget.js)"
run --root "$F"
assert_rc 1 "two fresh markers and one stale"
assert_count drift 0 "two fresh, one stale"
assert_count stale 1 "two fresh, one stale"
assert_count incomplete 0 "two fresh, one stale"
assert_count fresh 2 "two fresh, one stale"

# Precedence: an assessment that could not finish outranks one that finished badly.
rm "$F/memory-bank/techContext.md"
write_progress "$F/memory-bank" "- Unknowable (verified: 0123456789abcdef0123456789abcdef01234567 src/widget.js)"
run --root "$F"
assert_count drift 1 "drift and incomplete together"
assert_count incomplete 1 "drift and incomplete together"
assert_rc 2 "incomplete outranks drift"
write_bank "$F/memory-bank"

# =============================================================================
# 10. Failures are findings, never silence (regressions for the R1 review)
# =============================================================================
# A git subprocess that fails must never leave the report reading clean. The
# shim fails only `git diff`; everything else passes through to real git.
mkdir -p "$tmp/shim"
{
  printf '#!/bin/sh\n'
  printf 'for a in "$@"; do [ "$a" = "diff" ] && exit 128; done\n'
  printf 'exec %s "$@"\n' "$(command -v git)"
} > "$tmp/shim/git"
chmod +x "$tmp/shim/git"
rc=0
OUT="$(PATH="$tmp/shim:$PATH" "$CHECK" check --root "$B" 2>&1)" || rc=$?
RC="$rc"
assert_rc 2 "git diff failure during the baseline pass"
assert_count incomplete 1 "git diff failure"
assert_has "framework baseline comparison failed" "a failed baseline diff is INCOMPLETE, not a clean baseline"
[ "$(baseline_field)" = "unavailable" ] && ok "a failed comparison never reports a baseline" || bad "baseline field is '$(baseline_field)'"

write_progress "$F/memory-bank" "- Needs a diff (verified: $BASE src/widget.js)"
rc=0
OUT="$(PATH="$tmp/shim:$PATH" "$CHECK" check --root "$F" 2>&1)" || rc=$?
RC="$rc"
assert_rc 2 "git diff failure during the marker pass"
assert_count fresh 0 "git diff failure never counts a marker fresh"
assert_has "git diff failed for the declared evidence" "a failed evidence diff is INCOMPLETE"

# A non-object anchor is a finding, not a jq schema error escaping as exit 5.
printf '[]\n' > "$F/.serel-memory.json"
run --root "$F"
assert_rc 2 "array anchor"
assert_count incomplete 1 "array anchor"
assert_has "anchor must be a JSON object (got array)" "a non-object anchor is INCOMPLETE"
assert_one_summary "array anchor still prints a summary"
anchor "$F" "v1.0.0"

# Missing operands are usage errors (exit 2), never a bare exit 1.
for bad_args in --root --scope; do
  rc=0
  "$CHECK" check "$bad_args" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "2" ] && ok "missing operand to $bad_args — exit 2" || bad "missing operand to $bad_args — exit $rc, want 2"
done

# Fence rules: a ```` block quoting ``` stays one fence, and a live marker after
# it is still parsed. Two markers on one line are both parsed.
{
  printf '# Progress\n\n## What works\n\n'
  printf '````text\n```\nverified: %s src/gadget.js\n```\n````\n\n' "$BASE"
  printf -- '- Live again (verified: %s src/widget.js)\n' "$BASE"
} > "$F/memory-bank/progress.md"
run --root "$F"
assert_rc 0 "nested fence keeps decorative markers decorative"
assert_count fresh 1 "nested fence"
assert_count stale 0 "nested fence"

write_progress "$F/memory-bank" "- Two claims, one line (verified: $BASE src/widget.js) and (verified: $BASE src/gadget.js)"
run --root "$F"
assert_rc 1 "two markers on one line"
assert_count fresh 1 "two markers on one line"
assert_count stale 1 "the second marker on a line is not skipped"
write_progress "$F/memory-bank" "- Renders"

# =============================================================================
# 11. Missing helpers, retention warnings, staged and directory evidence
# =============================================================================
mv "$F/hooks/lib/rotate-check.sh" "$tmp/rotate-check.sh"
run --root "$F"
assert_rc 2 "retention helper missing"
assert_has "^INCOMPLETE hooks/lib/rotate-check.sh retention helper missing" "a missing retention helper is INCOMPLETE"
mv "$tmp/rotate-check.sh" "$F/hooks/lib/rotate-check.sh"

mv "$F/hooks/lib/resolve-scope.sh" "$tmp/resolve-scope.sh"
run --root "$F"
assert_rc 2 "scope resolver missing"
assert_has "^INCOMPLETE hooks/lib/resolve-scope.sh scope resolver missing" "a missing resolver is INCOMPLETE"
assert_one_summary "a missing resolver still prints a summary"
mv "$tmp/resolve-scope.sh" "$F/hooks/lib/resolve-scope.sh"

# UNSUPPORTED structure and an overage that cannot be rotated are both WARN.
{
  printf '# Progress\n\n## Status\n\n**Phase:** building\n\n## Recent milestones\n\n'
  i=1
  while [ "$i" -le 11 ]; do printf -- '- 2026-01-%02d milestone %d\n' "$i" "$i"; i=$((i + 1)); done
  printf '\n### A sub-heading the helper cannot place\n\n- 2026-02-01 later\n'
} > "$F/memory-bank/progress.md"
run --root "$F"
assert_rc 0 "unsupported structure is exit-neutral"
assert_has "^WARN memory-bank/progress.md retention cannot see part of progress.md" "UNSUPPORTED is a WARN"

{
  printf '# Active Context\n\n## Current focus\n\n'
  i=1
  while [ "$i" -le 210 ]; do printf 'Current state line %d that cannot be rotated away.\n' "$i"; i=$((i + 1)); done
} > "$F/memory-bank/activeContext.md"
run --root "$F"
assert_rc 0 "unrotatable overage is exit-neutral"
assert_has "^WARN memory-bank/activeContext.md over the retention target: OVERAGE-REMAINS" "OVERAGE-REMAINS is a WARN"
write_bank "$F/memory-bank"

# Staged evidence is dirty evidence.
echo "widget staged" >> "$F/src/widget.js"
git -C "$F" add src/widget.js
write_progress "$F/memory-bank" "- Staged (verified: $BASE src/widget.js)"
run --root "$F"
assert_rc 2 "staged evidence"
assert_has "evidence dirty in worktree: src/widget.js" "staged evidence is INCOMPLETE, not fresh"
git -C "$F" reset --quiet HEAD src/widget.js
git -C "$F" checkout -- src/widget.js

# A tracked directory is valid evidence; an untracked file inside it is dirt.
write_progress "$F/memory-bank" "- Whole tree (verified: $BASE src)"
run --root "$F"
assert_rc 1 "directory evidence resolves"
assert_count stale 1 "directory evidence compares the whole tree"
echo "brand new" > "$F/src/extra.js"
run --root "$F"
assert_rc 2 "untracked file inside directory evidence"
assert_has "evidence dirty in worktree: src" "an untracked file under directory evidence is INCOMPLETE"
rm "$F/src/extra.js"

if [ "$fail" -eq 0 ]; then echo "check OK"; fi
exit "$fail"
