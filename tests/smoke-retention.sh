#!/usr/bin/env bash
# Retention contract test — validates hooks/lib/rotate-check.sh SELECTION
# against fixtures, then applies its selections mechanically to prove the
# rotation is lossless and the predictions are exact.
#
# Coverage is selection/contract validation: in real use the agent applies
# the approved rotation; here a tiny fixture consumer stands in for it.
# shellcheck disable=SC2015  # ok/bad never fail, so `A && ok || bad` is a plain either/or here
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C

CHECK="hooks/lib/rotate-check.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp"/{f1,f2,f2min,f2live,f3,f4,f5,f5live,f6,f6live}
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

field() { printf '%s\n' "$1" | sed -n "s/^$2: //p" | head -1; }

# Mechanical consumer: apply the helper's SELECT spans exactly as the contract
# says an agent should — append verbatim to the archive, delete the ranges from
# the live file (highest first), add the pointer under the first "## Recent"
# heading when missing.
apply_rotation() {
  local file="$1" report="$2" archive="$3" spans base
  spans="$(printf '%s\n' "$report" | sed -n 's/^SELECT: .* lines: *//p')"
  base="$(basename "$file" .md)"
  [ -n "$spans" ] || return 0
  [ -f "$archive" ] || printf '# Rotated entries from %s.md\n' "$base" > "$archive"
  for sp in $spans; do
    sed -n "${sp%-*},${sp#*-}p" "$file" >> "$archive"
  done
  # delete highest range first so earlier line numbers stay valid
  for sp in $(printf '%s\n' "$spans" | tr ' ' '\n' | sort -t- -k1,1nr); do
    sed -i.bak "${sp%-*},${sp#*-}d" "$file" && rm -f "$file.bak"
  done
  if printf '%s\n' "$report" | grep -q '^POINTER: missing'; then
    awk -v ptr="Older entries: archive/${base}-*.md" '
      { print }
      !done && /^## Recent / { print ptr; done = 1 }
    ' "$file" > "$file.new" && mv "$file.new" "$file"
  fi
}

# Every selected span must lie inside rotatable regions: no protected heading
# and no heading other than a dated "## Recent changes (" inside a span.
assert_spans_clean() {
  local file="$1" report="$2" spans sp
  spans="$(printf '%s\n' "$report" | sed -n 's/^SELECT: .* lines: *//p')"
  for sp in $spans; do
    if sed -n "${sp%-*},${sp#*-}p" "$file" | grep -E '^## ' | grep -qvE '^## Recent changes \('; then
      bad "$3: span $sp crosses a non-rotatable heading"
    fi
  done
}

assert_exact_prediction() {
  local file="$1" report="$2" pl pb
  pl="$(printf '%s\n' "$report" | sed -n 's/^PREDICTED: .*lines=\([0-9]*\).*/\1/p')"
  pb="$(printf '%s\n' "$report" | sed -n 's/^PREDICTED: .*bytes=\([0-9]*\).*/\1/p')"
  [ "$(wc -l < "$file" | tr -d ' ')" = "$pl" ] || bad "$3: predicted lines=$pl, got $(wc -l < "$file" | tr -d ' ')"
  [ "$(wc -c < "$file" | tr -d ' ')" = "$pb" ] || bad "$3: predicted bytes=$pb, got $(wc -c < "$file" | tr -d ' ')"
}

# --- Fixture builders --------------------------------------------------------
active_head() {
  cat <<'H'
# Active Context

## Current focus

Shipping the widget. This line must never move.

## Checkpoint

- Branch: feature/widget — next step: wire the API.

## Next steps

1. Wire the API.

## Open questions

- Which auth flow?

## Notes for next session

- Remember the staging DB is read-only.

H
}
dated_section() {  # $1 = date label, $2 = lines of body
  local i
  echo "## Recent changes ($1 session)"
  echo ""
  for i in $(seq 1 "$2"); do
    echo "- Item $i of the $1 session: some detail that fills a line of history."
  done
  echo ""
}

# --- F1: template-shaped bank → NO-OP, no units -----------------------------
cp memory-bank/activeContext.md "$tmp/f1/activeContext.md"
r="$("$CHECK" "$tmp/f1/activeContext.md" activeContext)"
[ "$(field "$r" RESULT)" = "NO-OP" ] && [ "$(field "$r" ROTATABLE)" = "0 units (oldest last)" ] \
  && ok "F1 template bank is NO-OP" || bad "F1 template bank: $(field "$r" RESULT)"

# --- F2: dated sections over the LINE target ---------------------------------
{ active_head; for d in 2026-09 2026-08 2026-07 2026-06 2026-05 2026-04 2026-03; do dated_section "$d" 30; done; } > "$tmp/f2/activeContext.md"
r="$("$CHECK" "$tmp/f2/activeContext.md" activeContext)"
res="$(field "$r" RESULT)"
case "$res" in ROTATE\ *) ok "F2 over target → $res" ;; *) bad "F2 expected ROTATE, got $res" ;; esac
printf '%s\n' "$r" | grep -q '^PROTECTED: Current focus; Checkpoint; Next steps; Open questions; Notes for next session' \
  && ok "F2 all five protected sections detected" || bad "F2 protected list: $(field "$r" PROTECTED)"
printf '%s\n' "$r" | grep -q '^ROTATABLE: 7 units' && ok "F2 seven dated sections found" || bad "F2 unit count"
sel="$(field "$r" SELECT)"
case "$sel" in units\ *..7\ *) ok "F2 selection is a suffix ending at the oldest unit" ;; *) bad "F2 selection not oldest-last: $sel" ;; esac
assert_spans_clean "$tmp/f2/activeContext.md" "$r" F2
# Independent expectation: the two oldest dated sections, computed from the
# fixture itself (heading line .. last non-blank line before the next H2).
exp_spans="$(awk '/^## Recent changes \(2026-04 session\)/{a=NR} /^## Recent changes \(2026-03 session\)/{b=NR} NF{last=NR} END{print a"-"(b-2)" "b"-"last}' "$tmp/f2/activeContext.md")"
[ "$(printf '%s\n' "$sel" | sed 's/.*lines: *//')" = "$exp_spans" ] && ok "F2 spans match independently computed ranges ($exp_spans)" || bad "F2 spans $(printf '%s\n' "$sel" | sed 's/.*lines: *//') != expected $exp_spans"
pl="$(printf '%s\n' "$r" | sed -n 's/^PREDICTED: lines=\([0-9]*\).*/\1/p')"
[ "$pl" -le 200 ] && ok "F2 predicted lines $pl <= 200" || bad "F2 predicted lines $pl > 200"
# The selection must be MINIMAL: one fewer unit would still be over target.
nsel="$(printf '%s\n' "$sel" | sed 's/.*(\([0-9]*\)).*/\1/')"
first_sel="$(printf '%s\n' "$sel" | sed 's/^units \([0-9]*\)\.\..*/\1/')"
if [ "$nsel" -gt 1 ]; then
  cp "$tmp/f2/activeContext.md" "$tmp/f2min/activeContext.md"
  r_min="$(printf '%s\n' "$r" | sed "s/^SELECT: units $first_sel\.\.7 ([0-9]*) lines: *[0-9]*-[0-9]* /SELECT: units $((first_sel+1))..7 (x) lines: /")"
  apply_rotation "$tmp/f2min/activeContext.md" "$r_min" "$tmp/f2min/archive.md"
  [ "$(wc -l < "$tmp/f2min/activeContext.md" | tr -d ' ')" -gt 200 ] \
    && ok "F2 selection is minimal (one fewer unit stays over target)" \
    || bad "F2 selection not minimal"
fi
# Apply for real: lossless, exact, rerun NO-OP.
cp "$tmp/f2/activeContext.md" "$tmp/f2live/activeContext.md"
expected="$(for sp in $(printf '%s\n' "$sel" | sed 's/.*lines: *//'); do sed -n "${sp%-*},${sp#*-}p" "$tmp/f2/activeContext.md"; done)"
apply_rotation "$tmp/f2live/activeContext.md" "$r" "$tmp/f2live/archive.md"
assert_exact_prediction "$tmp/f2live/activeContext.md" "$r" F2
[ "$(tail -n +2 "$tmp/f2live/archive.md")" = "$expected" ] && ok "F2 archive holds the rotated sections verbatim" || bad "F2 archive content differs"
grep -q '^Older entries: archive/activeContext-\*\.md$' "$tmp/f2live/activeContext.md" && ok "F2 pointer line added" || bad "F2 pointer missing"
grep -q 'This line must never move\.' "$tmp/f2live/activeContext.md" && ok "F2 protected content intact" || bad "F2 protected content lost"
grep -q 'staging DB is read-only' "$tmp/f2live/activeContext.md" && ok "F2 notes for next session intact" || bad "F2 notes rotated"
r2="$("$CHECK" "$tmp/f2live/activeContext.md" activeContext)"
[ "$(field "$r2" RESULT)" = "NO-OP" ] && ok "F2 rerun is NO-OP" || bad "F2 rerun: $(field "$r2" RESULT)"
printf '%s\n' "$r2" | grep -q '^POINTER: present' && ok "F2 rerun sees the pointer" || bad "F2 rerun pointer missing"

# --- F3: protected content alone over target → OVERAGE-REMAINS, nothing selected
{ echo "# Active Context"; echo; echo "## Current focus"; echo; for i in $(seq 1 230); do echo "- current item $i"; done; } > "$tmp/f3/activeContext.md"
r="$("$CHECK" "$tmp/f3/activeContext.md" activeContext)"
case "$(field "$r" RESULT)" in OVERAGE-REMAINS*) ok "F3 protected-only overage reported" ;; *) bad "F3: $(field "$r" RESULT)" ;; esac
printf '%s\n' "$r" | grep -q '^SELECT:' && bad "F3 selected something in protected content" || ok "F3 nothing selected"

# --- F4: unsupported structure (no Recent changes) over target ----------------
{ active_head; for i in 1 2 3; do echo "## Previous focus (S$i)"; echo; for j in $(seq 1 70); do echo "- older note $i.$j"; done; echo; done; } > "$tmp/f4/activeContext.md"
r="$("$CHECK" "$tmp/f4/activeContext.md" activeContext)"
case "$(field "$r" RESULT)" in OVERAGE-REMAINS*) ok "F4 unsupported structure left untouched, overage reported" ;; *) bad "F4: $(field "$r" RESULT)" ;; esac
printf '%s\n' "$r" | grep -q '^ROTATABLE: 0 units' && ok "F4 zero units" || bad "F4 found units in unsupported structure"

# --- F5: progress with 14 milestones → rotate the 4 oldest -------------------
{
  sed -n '1,/^## Recent milestones/p' memory-bank/progress.md
  echo ""
  for i in $(seq 14 -1 1); do
    echo "- Milestone $i shipped (2026-0$(( (i % 9) + 1 ))-01)"
    [ $((i % 3)) -eq 0 ] && echo "  continuation line for milestone $i"
  done
} > "$tmp/f5/progress.md"
r="$("$CHECK" "$tmp/f5/progress.md" progress)"
[ "$(field "$r" RESULT)" = "ROTATE 4" ] && ok "F5 progress rotates 4 of 14" || bad "F5: $(field "$r" RESULT)"
[ "$(field "$r" SELECT | cut -d' ' -f1-3)" = "units 11..14 (4)" ] && ok "F5 selects units 11..14" || bad "F5 select: $(field "$r" SELECT)"
assert_spans_clean "$tmp/f5/progress.md" "$r" F5
printf '%s\n' "$r" | grep -q '^PROTECTED: Status; What works; In progress; What'"'"'s left to build; Known issues' \
  && ok "F5 progress protected sections detected" || bad "F5 protected: $(field "$r" PROTECTED)"
cp "$tmp/f5/progress.md" "$tmp/f5live/progress.md"
expected="$(for sp in $(field "$r" SELECT | sed 's/.*lines: *//'); do sed -n "${sp%-*},${sp#*-}p" "$tmp/f5/progress.md"; done)"
apply_rotation "$tmp/f5live/progress.md" "$r" "$tmp/f5live/archive.md"
assert_exact_prediction "$tmp/f5live/progress.md" "$r" F5
[ "$(tail -n +2 "$tmp/f5live/archive.md")" = "$expected" ] && ok "F5 archive holds the 4 oldest milestones verbatim" || bad "F5 archive content differs"
grep -q 'continuation line for milestone 3$' "$tmp/f5live/archive.md" && ok "F5 multi-line bullet moved whole" || bad "F5 continuation line split"
r2="$("$CHECK" "$tmp/f5live/progress.md" progress)"
[ "$(field "$r2" RESULT)" = "NO-OP" ] && ok "F5 rerun is NO-OP" || bad "F5 rerun: $(field "$r2" RESULT)"
printf '%s\n' "$r2" | grep -q '^CURRENT: milestones=10' && ok "F5 ten milestones remain" || bad "F5 count: $(field "$r2" CURRENT)"

# --- F6: unsuffixed Recent changes bullets over the BYTE target --------------
{ active_head; echo "## Recent changes"; echo; for i in $(seq 1 60); do printf -- '- Entry %02d: %s\n' "$i" "$(printf 'x%.0s' $(seq 1 200))"; done; } > "$tmp/f6/activeContext.md"
r="$("$CHECK" "$tmp/f6/activeContext.md" activeContext)"
case "$(field "$r" RESULT)" in ROTATE\ *) ok "F6 byte overage → $(field "$r" RESULT)" ;; *) bad "F6: $(field "$r" RESULT)" ;; esac
[ "$(wc -l < "$tmp/f6/activeContext.md" | tr -d ' ')" -le 200 ] && ok "F6 fixture is under the line cap (bytes drive it)" || bad "F6 fixture over line cap"
cp "$tmp/f6/activeContext.md" "$tmp/f6live/activeContext.md"
apply_rotation "$tmp/f6live/activeContext.md" "$r" "$tmp/f6live/archive.md"
assert_exact_prediction "$tmp/f6live/activeContext.md" "$r" F6
[ "$(wc -c < "$tmp/f6live/activeContext.md" | tr -d ' ')" -le 12000 ] && ok "F6 rotated file under 12000 bytes" || bad "F6 still over bytes"
r2="$("$CHECK" "$tmp/f6live/activeContext.md" activeContext)"
[ "$(field "$r2" RESULT)" = "NO-OP" ] && ok "F6 rerun is NO-OP" || bad "F6 rerun: $(field "$r2" RESULT)"

# --- F7: a fenced "## Recent changes (...)" inside Current focus is not a section
mkdir -p "$tmp/f7"
{ echo "# Active Context"; echo; echo "## Current focus"; echo; echo "Example of the archive layout:"; echo '```'; echo "## Recent changes (2020-01 session)"; echo "- not a real entry"; echo '```'; for i in $(seq 1 210); do echo "- current item $i"; done; echo; echo "## Notes for next session"; echo; echo "- keep me"; } > "$tmp/f7/activeContext.md"
r="$("$CHECK" "$tmp/f7/activeContext.md" activeContext)"
printf '%s\n' "$r" | grep -q '^ROTATABLE: 0 units' && ok "F7 fenced heading ignored (0 units)" || bad "F7 fenced heading counted: $(field "$r" ROTATABLE)"
printf '%s\n' "$r" | grep -q '^SELECT:' && bad "F7 selected protected content" || ok "F7 nothing selected"

# --- F8: a ### sub-heading inside a bullet section stops unit collection ------
mkdir -p "$tmp/f8"
{ active_head; echo "## Recent changes"; echo; for i in $(seq 1 30); do printf -- '- Entry %02d: %s\n' "$i" "$(printf 'x%.0s' $(seq 1 200))"; done; echo; echo "### Sub-section that is not a bullet"; echo; for i in $(seq 31 60); do printf -- '- Entry %02d: %s\n' "$i" "$(printf 'y%.0s' $(seq 1 200))"; done; } > "$tmp/f8/activeContext.md"
r="$("$CHECK" "$tmp/f8/activeContext.md" activeContext)"
printf '%s\n' "$r" | grep -q '^UNSUPPORTED: sub-heading' && ok "F8 sub-heading reported as unsupported" || bad "F8 no UNSUPPORTED line"
printf '%s\n' "$r" | grep -q '^ROTATABLE: 30 units' && ok "F8 only the 30 bullets before the sub-heading are units" || bad "F8 units: $(field "$r" ROTATABLE)"
sp="$(field "$r" SELECT | sed 's/.*lines: *//')"
for x in $sp; do [ "${x#*-}" -lt "$(grep -n '^### ' "$tmp/f8/activeContext.md" | cut -d: -f1)" ] || bad "F8 span $x reaches past the sub-heading"; done
ok "F8 no span crosses the sub-heading"

# --- F9: every dated section must go → newest heading + pointer survive ------
mkdir -p "$tmp/f9" "$tmp/f9live"
{ echo "# Active Context"; echo; echo "## Current focus"; echo; for i in $(seq 1 190); do echo "- current item $i"; done; echo; dated_section 2026-09 8; dated_section 2026-08 8; } > "$tmp/f9/activeContext.md"
r="$("$CHECK" "$tmp/f9/activeContext.md" activeContext)"
[ "$(field "$r" SELECT | cut -d' ' -f1-3)" = "units 1..2 (2)" ] && ok "F9 both sections selected" || bad "F9 select: $(field "$r" SELECT)"
cp "$tmp/f9/activeContext.md" "$tmp/f9live/activeContext.md"
apply_rotation "$tmp/f9live/activeContext.md" "$r" "$tmp/f9live/archive.md"
assert_exact_prediction "$tmp/f9live/activeContext.md" "$r" F9
grep -q '^## Recent changes (2026-09 session)$' "$tmp/f9live/activeContext.md" && ok "F9 newest heading kept as the pointer's home" || bad "F9 newest heading rotated away"
grep -q '^Older entries: archive/activeContext-\*\.md$' "$tmp/f9live/activeContext.md" && ok "F9 pointer present" || bad "F9 pointer missing"
grep -c '^- Item ' "$tmp/f9live/archive.md" | grep -qx 16 && ok "F9 all 16 items archived verbatim" || bad "F9 archive item count: $(grep -c '^- Item ' "$tmp/f9live/archive.md")"
case "$(field "$r" RESULT)" in OVERAGE-REMAINS*|ROTATE*) ok "F9 result reported ($(field "$r" RESULT | cut -c1-15))" ;; *) bad "F9 result: $(field "$r" RESULT)" ;; esac
r2="$("$CHECK" "$tmp/f9live/activeContext.md" activeContext)"
printf '%s\n' "$r2" | grep -q '^POINTER: present' && ok "F9 rerun sees the pointer" || bad "F9 rerun pointer"
printf '%s\n' "$r2" | grep -q '^SELECT:' && bad "F9 rerun selected again" || ok "F9 rerun selects nothing"

# --- Usage errors ------------------------------------------------------------
"$CHECK" "$tmp/f1/activeContext.md" bogus >/dev/null 2>&1 && bad "bad kind accepted" || ok "bad kind rejected (exit 2)"
"$CHECK" "$tmp/f1/does-not-exist.md" activeContext >/dev/null 2>&1 && bad "missing file accepted" || ok "missing file rejected"

if [ "$fail" -eq 0 ]; then echo "retention OK"; fi
exit "$fail"
