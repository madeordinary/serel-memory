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

# An initialized bank with label-only bullets carrying real text is NOT template-only.
write_bank "$T/memory-bank"
run --root "$T"
assert_count drift 0 "initialized bank with label bullets is not flagged"

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

mv "$F/.serel-memory.json" "$tmp/saved-anchor.json"
run --root "$F"
assert_rc 2 "anchor missing"
assert_has "provenance anchor missing" "no anchor at all is INCOMPLETE"
mv "$tmp/saved-anchor.json" "$F/.serel-memory.json"

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

if [ "$fail" -eq 0 ]; then echo "check OK"; fi
exit "$fail"
