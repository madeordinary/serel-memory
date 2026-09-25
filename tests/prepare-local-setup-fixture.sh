#!/usr/bin/env bash
# Build a synthetic repository with a local (Git-excluded) Serel Memory install
# for the manual fresh-session CLI exercise in tests/local-setup-acceptance.md.
#
# usage: prepare-local-setup-fixture.sh <new-directory> [team|fresh|blank|scoped]
#   team   (default) the repository tracks its own AGENTS.md and CLAUDE.md;
#          the bank is seeded with synthetic content
#   fresh  no instruction files, so the installer adds a local AGENTS.md;
#          the bank is seeded with synthetic content
#   blank  no instruction files, code plus a spec, and the bank left blank,
#          to exercise start's setup routing
#   scoped as fresh, plus tracked code in projects/example/ and, after the
#          install, "scopes": ["projects"] added to the local anchor; no
#          project bank exists, to exercise the local-install scope stop
#
# The installer runs from this checkout. Everything here is synthetic.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
usage() { echo "usage: $0 <new-directory> [team|fresh|blank|scoped]" >&2; exit 1; }
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
target="$1"
variant="${2:-team}"
case "$variant" in team|fresh|blank|scoped) ;; *) usage ;; esac
if [ "$variant" = scoped ] && ! command -v jq >/dev/null 2>&1; then
  echo "the scoped variant needs jq: scoped banks are disabled without it" >&2
  exit 1
fi
if [ -e "$target" ] || [ -L "$target" ]; then
  echo "target must not exist" >&2
  exit 1
fi
mkdir -p "$target"
target="$(cd "$target" && pwd -P)"
cd "$target"
git -c core.hooksPath=/dev/null init -q
git config user.name "Synthetic acceptance fixture"
git config user.email "fixture@example.com"
git config core.hooksPath /dev/null
git config commit.gpgsign false

cat >README.md <<'FIXTURE'
# Ledger Lite

Synthetic acceptance data, not a real product. `ledger.sh` totals the amount
column of an expenses CSV.
FIXTURE
cat >ledger.sh <<'FIXTURE'
#!/usr/bin/env bash
# Total the second column of a CSV with a header row.
set -euo pipefail
awk -F, 'NR > 1 { total += $2 } END { printf "%.2f\n", total }' "${1:?usage: ledger.sh <file.csv>}"
FIXTURE
chmod +x ledger.sh
printf 'date,amount\n2026-09-01,12.50\n2026-09-02,7.25\n' >expenses.csv
if [ "$variant" = team ]; then
  cat >AGENTS.md <<'FIXTURE'
# Team instructions (synthetic)

Run `./ledger.sh expenses.csv` before committing. This file belongs to the
team; the local Serel Memory install must leave it byte-for-byte unchanged.
FIXTURE
  printf '@AGENTS.md\n\nTeam Claude notes (synthetic): keep answers short.\n' >CLAUDE.md
fi
if [ "$variant" = blank ]; then
  mkdir docs
  cat >docs/spec.md <<'FIXTURE'
# Ledger Lite spec (synthetic)

- Total the amount column of an expenses CSV. (Built.)
- Planned: a `--since <date>` filter and a per-month summary. (Not built.)
FIXTURE
fi
if [ "$variant" = scoped ]; then
  mkdir -p projects/example
  cat >projects/example/README.md <<'FIXTURE'
# Receipt Scan (synthetic)

A second project in this repository: `scan.sh` counts the receipts in a
folder. Synthetic acceptance data, not a real product.
FIXTURE
  cat >projects/example/scan.sh <<'FIXTURE'
#!/usr/bin/env bash
# Count the receipt images in a folder.
set -euo pipefail
find "${1:?usage: scan.sh <folder>}" -maxdepth 1 -name '*.jpg' | wc -l
FIXTURE
  chmod +x projects/example/scan.sh
fi
git add -A
git commit -qm "Synthetic starting point"

# Existing work the install must preserve: staged, unstaged, and untracked.
printf '2026-09-03,3.00\n' >>expenses.csv
git add expenses.csv
printf '# usage: ledger.sh <file.csv>\n' >>ledger.sh
printf 'scratch notes (untracked)\n' >scratch.txt

bash "$root/install.sh" "$target" --local --apply >/dev/null

if [ "$variant" != blank ]; then
  # Stand-in for an approved /init-memory: synthetic, clearly marked content.
  cat >memory-bank/projectbrief.md <<'FIXTURE'
# Project Brief

## What

Ledger Lite (synthetic acceptance fixture): a command-line tool that totals
the amount column of an expenses CSV.

## Why

Fixture data for checking that a fresh agent session reads a local bank.
FIXTURE
  cat >memory-bank/productContext.md <<'FIXTURE'
# Product Context

## The user

One person tracking household expenses in a spreadsheet export.
FIXTURE
  cat >memory-bank/systemPatterns.md <<'FIXTURE'
# System Patterns

## Architecture

One Bash script using awk; no dependencies beyond a POSIX userland.
FIXTURE
  cat >memory-bank/techContext.md <<'FIXTURE'
# Tech Context

## Stack

Bash and awk. Run `./ledger.sh expenses.csv`.
FIXTURE
  cat >memory-bank/decisionLog.md <<'FIXTURE'
# Decision Log

## Active decisions

- 2026-09-01: amounts are summed as printed decimals, two places. Why: the
  exports never carry more precision. Status: accepted.
FIXTURE
  cat >memory-bank/activeContext.md <<'FIXTURE'
# Active Context

## Current focus

Add a `--since <date>` filter to `ledger.sh` (fixture token LEDGER-LITE-7731).

## Next steps

1. Parse `--since` before the file argument.
2. Skip rows whose date sorts before it.

## Open questions

- Should the filter include the given date? (Undecided.)
FIXTURE
  cat >memory-bank/progress.md <<'FIXTURE'
# Progress

## Status

Phase: prototype. Totals work; filtering is not built.

## What works

- Totals the amount column of a CSV with a header row.

## What's left to build

- The `--since` filter.
FIXTURE
  printf '%s\n' '- Keep ledger.sh dependency-free (synthetic rule).' >>.rules
fi

if [ "$variant" = scoped ]; then
  # Scopes listed after a local install: the exclusions still cover only the
  # root bank and .rules, so projects/example has no Git-excluded bank.
  anchor="$(cat .serel-memory.json)"
  case "$anchor" in
    *' }') printf '%s, "scopes": ["projects"] }\n' "${anchor% \}}" >.serel-memory.json ;;
    *) echo "unexpected anchor: $anchor" >&2; exit 1 ;;
  esac
  listed="$(bash hooks/lib/resolve-scope.sh --root "$target" --list)"
  [ "$listed" = "$(printf 'P\tprojects/example\tuninitialized')" ] ||
    { echo "scope setup failed: $listed" >&2; exit 1; }
  [ ! -e projects/example/memory-bank ] || { echo "a project bank exists" >&2; exit 1; }
  git check-ignore -q .serel-memory.json || { echo "the anchor is not Git-excluded" >&2; exit 1; }
fi

echo "Fixture ready: $target ($variant)"
echo "git status (the install is invisible; only the fixture's own work shows):"
git status --short
