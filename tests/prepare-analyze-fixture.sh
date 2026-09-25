#!/usr/bin/env bash
# Build a synthetic repository for the manual dual-CLI acceptance exercise.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ "$#" -eq 1 ] || { echo "usage: $0 <new-directory>" >&2; exit 1; }
target="$1"
if [ -e "$target" ] || [ -L "$target" ]; then
  echo "target must not exist" >&2
  exit 1
fi
mkdir -p "$target"
target="$(cd "$target" && pwd -P)"
mkdir -p "$target/.claude" "$target/.agents" "$target/docs" "$target/bin" "$target/tests" "$target/memory-bank/verification"
cp "$root/AGENTS.md" "$target/"
cp -R "$root/.claude/commands" "$target/.claude/"
cp -R "$root/.agents/skills" "$target/.agents/"
cp -R "$root/hooks" "$target/"
cp "$root/docs/workflow-contract.md" "$root/docs/cross-agent-review.md" "$root/docs/serel-setup.md" "$target/docs/"
cp "$root/bin/serel-memory" "$target/bin/"
cd "$target"
git -c core.hooksPath=/dev/null init -q
git config user.name "Synthetic acceptance fixture"
git config user.email "fixture@example.com"
git config core.hooksPath /dev/null
git config commit.gpgsign false
printf '%s\n' '{"upstream":"madeordinary/serel-memory","ref":"fixture-no-framework-baseline","linked":false}' > .serel-memory.json
printf '%s\n' '__pycache__/' > .gitignore
cat > README.md <<'FIXTURE'
# Export Queue

Synthetic acceptance data, not a real product or a real project's history.
The fixture builder creates actual local commits and one initial test run.
The initial revision has a CSV exporter and a 300-second cache TTL.
FIXTURE
cat > app.py <<'FIXTURE'
import csv
import io

CACHE_TTL_SECONDS = 300


def export_csv(tasks):
    output = io.StringIO(newline="")
    writer = csv.writer(output)
    writer.writerow(["id", "title", "done"])
    for task in tasks:
        writer.writerow([task["id"], task["title"], str(task["done"]).lower()])
    return output.getvalue()
FIXTURE
cat > tests/test_app.py <<'FIXTURE'
import csv
import io
import unittest
from app import CACHE_TTL_SECONDS, export_csv


class QueueTests(unittest.TestCase):
    def test_export_quotes_and_header(self):
        rows = list(csv.reader(io.StringIO(export_csv([
            {"id": 1, "title": 'A, "quoted" task', "done": False},
        ]))))
        self.assertEqual(rows, [["id", "title", "done"], ["1", 'A, "quoted" task', "false"]])

    def test_accepted_cache_ttl(self):
        self.assertEqual(CACHE_TTL_SECONDS, 300)
FIXTURE
git add .
git commit -qm "Implement CSV export and the accepted cache TTL"
base="$(git rev-parse HEAD)"
python3 -B -m unittest discover -s tests -v
cat > memory-bank/projectbrief.md <<'FIXTURE'
# Project Brief

## What
A synthetic local task queue used to evaluate memory accuracy audits.

## Success looks like
CSV export and a 300-second cache TTL work; a future desktop UI is optional.
FIXTURE
cat > memory-bank/productContext.md <<'FIXTURE'
# Product Context

## User problem
Users need to export local tasks without a network connection.

## UX goals
The planned desktop UI should support dragging tasks. It is not implemented.
FIXTURE
cat > memory-bank/systemPatterns.md <<'FIXTURE'
# System Patterns

## Architecture
The Python module exports CSV in memory using the standard library.
Cache TTL policy comes from the accepted decision in decisionLog.md.
FIXTURE
cat > memory-bank/techContext.md <<'FIXTURE'
# Tech Context

## Stack and checks
Python standard library. Run tests with `python3 -B -m unittest discover -s tests -v`.

## Current performance
The queue sustains 10,000 tasks per second. No benchmark result or procedure is recorded.
FIXTURE
cat > memory-bank/decisionLog.md <<'FIXTURE'
# Decision Log

## Active decisions
- Cache results for 300 seconds to avoid repeated work. Accepted; no replacement decision exists.
- A desktop UI with drag-and-drop is accepted for a later phase, not the current implementation.
FIXTURE
cat > memory-bank/activeContext.md <<'FIXTURE'
# Active Context

## Current focus
Finish implementing CSV export.

## Checkpoint
The next action is to write the exporter, then verify quoting and headers.

## Next steps
- Implement CSV export.
- Later, build the accepted desktop UI.
FIXTURE
cat > memory-bank/progress.md <<FIXTURE
# Progress

## What works
- Cache TTL is 300 seconds (verified: $base app.py tests/test_app.py).

## In progress
- CSV export still needs implementing.

## Recent milestones
- At the design kickoff, CSV export had not been implemented. This is historical context.
FIXTURE
cat > memory-bank/verification/export.md <<FIXTURE
# Export verification

## Recipe
Run Python unittest discovery and inspect the header and quoted title case.

## Records
- Fixture builder ran both tests successfully at revision $base.
  Evidence paths: app.py, tests/test_app.py. This records that revision only.
FIXTURE
printf '%s\n' '# Rules' '' '- Preserve the accepted TTL until a replacement decision is approved.' > .rules
git add memory-bank .rules
git commit -qm "Record a synthetic bank with discrepancies for the audit exercise"
# Leave a real working-tree mismatch after the recorded passing run.
sed 's/CACHE_TTL_SECONDS = 300/CACHE_TTL_SECONDS = 30/' app.py > app.py.next
mv app.py.next app.py
printf 'Fixture ready: %s\n' "$target"
printf 'Initial tests passed at %s; app.py now has an untested working-tree change.\n' "$base"
