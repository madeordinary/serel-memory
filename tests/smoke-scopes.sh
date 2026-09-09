#!/usr/bin/env bash
# Scoped banks (opt-in) — resolver contract + hook behavior.
#
# Builds a fixture repo with a root bank and three project roots, then drives
# hooks/lib/resolve-scope.sh through every documented case and checks both
# hooks: with scopes they list project selectors and read no project bank;
# without scopes their output is byte-identical to the v0.3.0 hooks.
# shellcheck disable=SC2015,SC2016  # ok/bad never fail (plain either/or); backticks in grep patterns are literal
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
R="$ROOT/hooks/lib/resolve-scope.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
GIT="git -c user.email=test@test -c user.name=smoke-scopes"

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required for this test (and for scopes)"; exit 1; }
git rev-parse --verify --quiet "v0.3.0^{commit}" >/dev/null \
  || { echo "FAIL: local tag v0.3.0 is required for the byte-identity baseline"; exit 1; }

# --- Fixture ------------------------------------------------------------------
F="$tmp/project"; mkdir -p "$F"; cd "$F"
git archive --format=tar --remote="$ROOT" HEAD memory-bank .rules 2>/dev/null | tar -x -C "$F" \
  || { cp -R "$ROOT/memory-bank" "$F/"; cp "$ROOT/.rules" "$F/"; }
mkdir -p projects/running/widget/memory-bank projects/running/gadget projects/watching/thing/memory-bank/sub docs
cp memory-bank/activeContext.md projects/running/widget/memory-bank/activeContext.md
echo "WIDGET-BANK-MARKER: must never appear in root hook output" >> projects/running/widget/memory-bank/activeContext.md
echo "- widget-only rule" > projects/running/widget/.rules
echo "- root rule" >> .rules
anchor_with()    { printf '{ "upstream": "local/serel-memory", "ref": "v0.4.0", "linked": false, "scopes": %s }\n' "$1" > .serel-memory.json; }
anchor_without() { printf '{ "upstream": "local/serel-memory", "ref": "v0.4.0", "linked": false }\n' > .serel-memory.json; }
anchor_without
$GIT init --quiet && $GIT add -A && $GIT commit --quiet -m "fixture"

# Older hooks for the no-scopes byte-identity baseline.
git -C "$ROOT" show v0.3.0:hooks/session-start.sh > "$tmp/old-session-start.sh"
git -C "$ROOT" show v0.3.0:hooks/pre-compact.sh   > "$tmp/old-pre-compact.sh"

res() { "$R" --root "$F" "$@"; }

# --- No scopes: everything resolves to the root, list says none -------------
[ "$(res)" = "$(printf '.\tmemory-bank\t.rules\t.rules\t-\tinitialized')" ] && ok "no scopes: root bank" || bad "no scopes: $(res)"
[ "$(res --list)" = "SCOPES: none" ] && ok "no scopes: list is none" || bad "no scopes list: $(res --list)"
(cd projects/watching/thing && "$R" --root "$F" | grep -q '^\.	') && ok "no scopes: nested cwd still resolves root" || bad "no scopes: nested cwd left the root"
res --scope projects/running/widget >/dev/null 2>&1 && bad "no scopes: --scope <project> accepted" || ok "no scopes: --scope <project> rejected"

# --- Scopes configured -------------------------------------------------------
anchor_with '["projects/running", "projects/watching"]'
[ "$(res --list)" = "$(printf 'P\tprojects/running/gadget\tuninitialized\nP\tprojects/running/widget\tinitialized\nP\tprojects/watching/thing\tinitialized')" ] \
  && ok "list: three project roots with state" || bad "list: $(res --list)"
[ "$(res)" = "$(printf '.\tmemory-bank\t.rules\t.rules\t-\tinitialized')" ] && ok "default (root cwd) → root" || bad "default: $(res)"
[ "$(res --scope .)" = "$(res)" ] && ok "--scope . → root" || bad "--scope ."
[ "$(res --scope projects/running/widget)" = "$(printf 'projects/running/widget\tprojects/running/widget/memory-bank\tprojects/running/widget/.rules\tprojects/running/widget/.rules\t.rules\tinitialized')" ] \
  && ok "--scope widget → its bank, its rules, inherits root .rules" || bad "widget: $(res --scope projects/running/widget)"
[ "$(res --scope projects/running/widget/)" = "$(res --scope projects/running/widget)" ] && ok "trailing slash tolerated" || bad "trailing slash"
[ "$(res --scope projects/running/gadget)" = "$(printf 'projects/running/gadget\tprojects/running/gadget/memory-bank\tprojects/running/gadget/.rules\t-\t.rules\tuninitialized')" ] \
  && ok "--scope gadget → valid but uninitialized, no local rules" || bad "gadget: $(res --scope projects/running/gadget)"
if out="$(res --scope projects/nope 2>"$tmp/err")"; then bad "unknown --scope accepted: $out"; else
  grep -q "unknown scope 'projects/nope'" "$tmp/err" && grep -q -- "--scope projects/running/widget" "$tmp/err" \
    && ok "unknown --scope exits 2 and lists selectors" || bad "unknown --scope stderr: $(cat "$tmp/err")"; fi
res --scope projects/running >/dev/null 2>&1 && bad "a scope ROOT was accepted as a project" || ok "scope root itself is not selectable"
[ "$(cd projects/watching/thing/memory-bank/sub && "$R" --root "$F" | cut -f1)" = "projects/watching/thing" ] \
  && ok "nested cwd → enclosing project" || bad "nested cwd: $(cd projects/watching/thing/memory-bank/sub && "$R" --root "$F")"
[ "$(cd docs && "$R" --root "$F" | cut -f1)" = "." ] && ok "cwd outside any project → root" || bad "cwd outside project"
[ "$(cd projects/watching/thing && "$R" --root "$F" --scope . | cut -f1)" = "." ] && ok "--scope . from nested cwd → root" || bad "--scope . from nested"
[ "$(res --cwd "$F/projects/running/gadget" | cut -f1,6)" = "$(printf 'projects/running/gadget\tuninitialized')" ] && ok "--cwd into an uninitialized project" || bad "--cwd gadget"

# --- Degraded configurations disable scopes with a warning --------------------
anchor_with '["projects", "projects/running"]'
res 2>"$tmp/err" | grep -q '^\.	' && grep -q "overlap" "$tmp/err" && ok "overlapping roots → warning, single-bank" || bad "overlap handling"
anchor_with '["nope"]'
res 2>"$tmp/err" | grep -q '^\.	' && grep -q "not a directory" "$tmp/err" && ok "missing root → warning, single-bank" || bad "missing root handling"
anchor_with '["../escape"]'
res 2>"$tmp/err" | grep -q '^\.	' && grep -q "invalid scope root" "$tmp/err" && ok "path escape → warning, single-bank" || bad "escape handling"
printf '{ "upstream": "x", "scopes": [ broken\n' > .serel-memory.json
res 2>"$tmp/err" | grep -q '^\.	' && grep -q "cannot parse" "$tmp/err" && ok "malformed anchor → warning, single-bank" || bad "malformed handling"
anchor_with '["projects/running", "projects/watching"]'
mkdir -p "$tmp/nojq"; for b in bash sh awk sed grep find sort cut git tr mktemp dirname basename cat printf wc head tail; do p="$(command -v "$b" 2>/dev/null || true)"; [ -n "$p" ] && ln -sf "$p" "$tmp/nojq/$b"; done
PATH="$tmp/nojq" "$R" --root "$F" 2>"$tmp/err" | grep -q '^\.	' && grep -q "jq is required" "$tmp/err" && ok "no jq → warning, single-bank" || bad "no-jq handling: $(cat "$tmp/err")"
[ "$(PATH="$tmp/nojq" "$R" --root "$F" --list 2>/dev/null)" = "SCOPES: none" ] && ok "no jq → list is none" || bad "no-jq list"

# --- Maintainer overlay composes inside the selected scope --------------------
mkdir memory-bank.local
[ "$(res --scope . | cut -f2-4)" = "$(printf 'memory-bank.local\tmemory-bank.local/.rules\t.rules')" ] \
  && ok "overlay without its .rules: write overlay, read root .rules" || bad "overlay no-rules: $(res --scope .)"
[ "$(res --scope projects/running/widget | cut -f5)" = ".rules" ] && ok "inherited rules fall back to root .rules" || bad "inherited fallback"
echo "- overlay rule" > memory-bank.local/.rules
[ "$(res --scope . | cut -f2-4)" = "$(printf 'memory-bank.local\tmemory-bank.local/.rules\tmemory-bank.local/.rules')" ] \
  && ok "overlay with .rules: read and write the overlay" || bad "overlay rules: $(res --scope .)"
[ "$(res --scope projects/running/widget | cut -f5)" = "memory-bank.local/.rules" ] && ok "inherited rules = repo's effective (overlay) rules" || bad "inherited overlay"
rm -rf memory-bank.local

# --- Hooks ---------------------------------------------------------------------
export CLAUDE_PROJECT_DIR="$F"
out="$(bash "$ROOT/hooks/session-start.sh")"
printf '%s\n' "$out" | grep -q '^### Scopes (project banks in this repo)' && ok "session-start: lists scopes" || bad "session-start: no scopes section"
printf '%s\n' "$out" | grep -q -- '^- --scope projects/running/widget \[initialized\]' && ok "session-start: widget selector" || bad "session-start: widget selector missing"
printf '%s\n' "$out" | grep -q -- '^- --scope projects/running/gadget \[uninitialized\]' && ok "session-start: gadget marked uninitialized" || bad "session-start: gadget"
printf '%s\n' "$out" | grep -q 'WIDGET-BANK-MARKER' && bad "session-start: READ a project bank" || ok "session-start: no project bank content"
printf '%s\n' "$out" | grep -q '^### memory-bank/activeContext.md' && ok "session-start: root bank loaded" || bad "session-start: root bank missing"
pc="$(cd projects/watching/thing && bash "$ROOT/hooks/pre-compact.sh")"
printf '%s\n' "$pc" | grep -q 'Scope resolved by cwd: `projects/watching/thing`' && ok "pre-compact: names the cwd scope" || bad "pre-compact: $(printf '%s\n' "$pc" | tail -2)"
printf '%s\n' "$pc" | grep -q 'effective bank `projects/watching/thing/memory-bank`' && ok "pre-compact: names the project bank" || bad "pre-compact bank"

# Without scopes: byte-identical to the v0.3.0 hooks on the same fixture.
anchor_without
new_ss="$(bash "$ROOT/hooks/session-start.sh")"; old_ss="$(bash "$tmp/old-session-start.sh")"
[ "$new_ss" = "$old_ss" ] && ok "session-start without scopes is byte-identical to v0.3.0" || { bad "session-start drifted from v0.3.0"; diff <(printf '%s\n' "$old_ss") <(printf '%s\n' "$new_ss") | head -20; }
new_pc="$(bash "$ROOT/hooks/pre-compact.sh")"; old_pc="$(bash "$tmp/old-pre-compact.sh")"
# The pre-compact text gained the retention step (documented change); compare everything else.
strip_ret() { sed '/^5\. Apply the update-memory retention step/,/^$/d'; }
[ "$(printf '%s\n' "$new_pc" | strip_ret)" = "$old_pc" ] && ok "pre-compact without scopes matches v0.3.0 (plus the retention step)" \
  || { bad "pre-compact drifted from v0.3.0"; diff <(printf '%s\n' "$old_pc") <(printf '%s\n' "$new_pc" | strip_ret) | head -20; }
# Overlay-only bank: hooks must still load it.
mkdir memory-bank.local && cp memory-bank/*.md memory-bank.local/ && rm -rf memory-bank
ov="$(bash "$ROOT/hooks/session-start.sh" 2>&1)"
printf '%s\n' "$ov" | grep -q '^### memory-bank.local/activeContext.md' && ok "session-start: overlay-only bank loads" || bad "session-start: overlay-only — headings: $(printf '%s\n' "$ov" | grep '^###' | tr '\n' '|')"
bash "$ROOT/hooks/pre-compact.sh" | grep -q 'pre-compact memory bank refresh' && ok "pre-compact: overlay-only bank still fires" || bad "pre-compact: overlay-only"

if [ "$fail" -eq 0 ]; then echo "scopes OK"; fi
exit "$fail"
