#!/usr/bin/env bash
# Build a synthetic repository for the manual memory-use exercise in
# tests/memory-use-acceptance.md (breakdown, review, update-memory).
#
# usage: prepare-memory-use-fixture.sh <new-directory> breakdown|review [with-lesson|without-lesson]
#        prepare-memory-use-fixture.sh <new-directory> update-memory
#
#   breakdown      clean main branch with an initialized bank
#   review         a notes-export branch with one candidate commit on top of main
#   update-memory  main plus an uncommitted change made "this session"; the
#                  bank never holds the target lesson, which the session found
#
# without-lesson omits one .rules bullet, the target lesson, and nothing else:
# paired builds share every other byte and the same commit metadata. Nothing
# in the workspace names the variant or the expected results.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
usage() {
  echo "usage: $0 <new-directory> breakdown|review [with-lesson|without-lesson]" >&2
  echo "       $0 <new-directory> update-memory" >&2
  exit 1
}
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
target="$1"
mode="$2"
variant="${3:-with-lesson}"
case "$mode" in
  breakdown|review) case "$variant" in with-lesson|without-lesson) ;; *) usage ;; esac ;;
  update-memory) [ "$#" -eq 2 ] || usage; variant=without-lesson ;;
  *) usage ;;
esac
if [ -e "$target" ] || [ -L "$target" ]; then
  echo "target must not exist" >&2
  exit 1
fi
parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" ||
  { echo "the target's parent directory must exist" >&2; exit 1; }
if git -C "$parent" rev-parse --git-dir >/dev/null 2>&1; then
  echo "target must be outside any Git work tree (this checkout included)" >&2
  exit 1
fi
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
target="$parent/$(basename "$target")"
mkdir "$target"
mkdir -p "$target/.claude" "$target/.agents" "$target/docs" "$target/bin" "$target/tests" "$target/memory-bank"
cp "$root/AGENTS.md" "$target/"
cp -R "$root/.claude/commands" "$target/.claude/"
cp -R "$root/.agents/skills" "$target/.agents/"
cp -R "$root/hooks" "$target/"
cp "$root/docs/workflow-contract.md" "$root/docs/cross-agent-review.md" "$root/docs/serel-setup.md" "$target/docs/"
cp "$root/bin/serel-memory" "$target/bin/"
cd "$target"
export PYTHONDONTWRITEBYTECODE=1
git -c core.hooksPath=/dev/null init -q
git symbolic-ref HEAD refs/heads/main
git config user.name "Synthetic acceptance fixture"
git config user.email "fixture@example.com"
git config core.hooksPath /dev/null
git config commit.gpgsign false
# Fixed dates keep paired builds' history metadata identical.
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2"; }
run_tests() {
  local out
  out="$(python3 -B -m unittest discover -s tests 2>&1)" ||
    { printf '%s\n' "$out" >&2; echo "fixture self-check failed: $1" >&2; exit 1; }
}

printf '%s\n' '{"upstream":"madeordinary/serel-memory","ref":"fixture-no-framework-baseline","linked":false}' > .serel-memory.json
printf '%s\n' '__pycache__/' > .gitignore
cat > README.md <<'FIXTURE'
# Crew Board

Synthetic acceptance data, not a real product or a real project's history.
`board.py` keeps crew tasks and exports a CSV that a partner's scheduling
system imports every night.
FIXTURE
cat > board.py <<'FIXTURE'
"""Crew Board: crew tasks and the nightly partner CSV export."""
import csv
import io

EXPORT_COLUMNS = ["id", "title", "due", "assignee", "done"]


def add_task(tasks, title, due, assignee, assignee_email, notes=""):
    task = {
        "id": len(tasks) + 1,
        # One line on the board, whatever was typed.
        "title": " ".join(title.split()),
        "due": due,
        "assignee": assignee,
        "assignee_email": assignee_email,
        # Notes keep their line breaks: crew leads write checklists in them.
        "notes": notes,
        "done": False,
    }
    tasks.append(task)
    return task


def export_csv(tasks):
    output = io.StringIO(newline="")
    writer = csv.writer(output)
    writer.writerow(EXPORT_COLUMNS)
    for task in tasks:
        writer.writerow([task["id"], task["title"], task["due"], task["assignee"],
                         str(task["done"]).lower()])
    return output.getvalue()
FIXTURE
cat > tests/test_export.py <<'FIXTURE'
import csv
import io
import unittest

from board import add_task, export_csv


def parse(text):
    return list(csv.reader(io.StringIO(text, newline="")))


class ExportTests(unittest.TestCase):
    def test_header_title_and_quoting(self):
        tasks = []
        add_task(tasks, "Check  ladders,\n east site", "2026-09-01", "Ana", "ana@example.com")
        self.assertEqual(parse(export_csv(tasks)), [
            ["id", "title", "due", "assignee", "done"],
            ["1", "Check ladders, east site", "2026-09-01", "Ana", "false"],
        ])


if __name__ == "__main__":
    unittest.main()
FIXTURE
run_tests "initial revision"
git add .
commit "2026-08-20T10:00:00Z" "Add the crew board and the partner CSV export"

cat > memory-bank/projectbrief.md <<'FIXTURE'
# Project Brief

## What

Crew Board (synthetic acceptance fixture, not a real product): tracks crew
tasks and exports them as CSV for a partner's nightly scheduling import.

## Success looks like

Crews see their tasks on the board, and dispatch sees the same tasks after the
nightly import.
FIXTURE
cat > memory-bank/productContext.md <<'FIXTURE'
# Product Context

## Users

Crew leads plan tasks on the board. Dispatch works in the partner's scheduling
system, which imports the board's CSV every night.

## UX goals

- The nightly import succeeds without manual fixes.
- Crew leads can write multi-line checklists in task notes.
FIXTURE
cat > memory-bank/systemPatterns.md <<'FIXTURE'
# System Patterns

## Architecture

One standard-library module, `board.py`. Tasks are dicts in a list;
`export_csv` writes the partner file with `csv.writer`, columns in
`EXPORT_COLUMNS` order. The partner maps columns by header name.
FIXTURE
cat > memory-bank/techContext.md <<'FIXTURE'
# Tech Context

## Stack

Python 3 standard library only; no third-party packages.

## Checks

Run the tests with `python3 -B -m unittest tests.test_export -v`.

## Operations

The partner's scheduling system imports the exported CSV nightly from a
shared folder.
FIXTURE
cat > memory-bank/decisionLog.md <<'FIXTURE'
# Decision Log

## Active decisions

- **Export dates as ISO 8601 (YYYY-MM-DD)** — the partner parses no other
  format. Status: accepted.
- **Keep assignee contact details (email, phone) out of the partner export**
  (2026-08-12) — the partner is not covered by our data-sharing agreement.
  Status: accepted (user-approved in the 2026-08-12 privacy review).
  Result: `export_csv` writes no contact columns.
- **Switch the partner export to JSON Lines** (2026-09-02) — easier to extend
  than CSV. Status: proposed by the agent; the user has not decided.
FIXTURE
cat > memory-bank/activeContext.md <<'FIXTURE'
# Active Context

## Current focus

Add task notes to the partner CSV export; crew leads asked for it so dispatch
sees their checklists.

## Next steps

1. Add a notes column to the export.
2. Keep the nightly partner import working.

## Open questions

- Should the export move to JSON Lines? Proposed by the agent; undecided.
FIXTURE
cat > memory-bank/progress.md <<'FIXTURE'
# Progress

## Status

Phase: in daily use by one crew. The partner imports the exported CSV nightly.

## What works

- Tasks with a title, due date, assignee, and notes; titles are kept to one line.
- CSV export of id, title, due, assignee, and done, with standard CSV quoting.

## What's left to build

- Export task notes to the partner (requested by crew leads).

## Known issues

- None recorded.
FIXTURE
cat > .rules <<'FIXTURE'
# Project Rules & Learnings

## User preferences

- Keep changes small and standard-library only; ask before adding a dependency.

## Gotchas

- The nightly backup restores `board.json` with `cp -p`; restoring as root leaves it unreadable by the `crew` service user. Restore as `crew`.
FIXTURE
# The target lesson: the only line without-lesson omits.
if [ "$variant" = with-lesson ]; then
  cat >> .rules <<'FIXTURE'
- The partner's scheduling importer ends a row at every line break, even inside a quoted CSV field (partner support ticket, 2026-07-14; their docs claim RFC 4180). In free-text export fields, replace `\r` and `\n` with a space in the export only, and test a value containing `\r\n`. Recheck if the partner announces support for quoted line breaks.
FIXTURE
fi
git add memory-bank .rules
commit "2026-09-02T16:00:00Z" "Record the project memory bank"

git mv tests/test_export.py tests/test_board.py
commit "2026-09-10T09:30:00Z" "Rename the test module to match board.py"
run_tests "main"
# The bank's recorded test command is a stale current fact: it must fail now.
if python3 -B -m unittest tests.test_export >/dev/null 2>&1; then
  echo "fixture self-check failed: the recorded test command still passes" >&2
  exit 1
fi

if [ "$mode" = review ]; then
  git checkout -q -b notes-export
  python3 - <<'FIXTURE'
import pathlib
board = pathlib.Path("board.py")
text = board.read_text()
text = text.replace('EXPORT_COLUMNS = ["id", "title", "due", "assignee", "done"]',
                    'EXPORT_COLUMNS = ["id", "title", "due", "assignee", "assignee_email", "done", "notes"]')
text = text.replace('task["assignee"],\n                         str(task["done"]).lower()])',
                    'task["assignee"],\n                         task["assignee_email"], str(task["done"]).lower(), task["notes"]])')
board.write_text(text)
FIXTURE
  cat > tests/test_board.py <<'FIXTURE'
import csv
import io
import unittest

from board import add_task, export_csv


def parse(text):
    return list(csv.reader(io.StringIO(text, newline="")))


class ExportTests(unittest.TestCase):
    def test_header_title_and_quoting(self):
        tasks = []
        add_task(tasks, "Check  ladders,\n east site", "2026-09-01", "Ana", "ana@example.com")
        self.assertEqual(parse(export_csv(tasks)), [
            ["id", "title", "due", "assignee", "assignee_email", "done", "notes"],
            ["1", "Check ladders, east site", "2026-09-01", "Ana", "ana@example.com", "false", ""],
        ])

    def test_notes_and_contact_exported(self):
        tasks = []
        add_task(tasks, "Stock van", "2026-09-03", "Cy", "cy@example.com", notes="- gloves, size L\n- tape")
        row = parse(export_csv(tasks))[1]
        self.assertEqual(row[4], "cy@example.com")
        self.assertEqual(row[6], "- gloves, size L\n- tape")


if __name__ == "__main__":
    unittest.main()
FIXTURE
  grep -q 'task\["notes"\]\])' board.py || { echo "fixture self-check failed: review edit did not apply" >&2; exit 1; }
  run_tests "notes-export"
  git add board.py tests/test_board.py
  commit "2026-09-20T14:00:00Z" "Export task notes and the assignee's email"
fi

if [ "$mode" = update-memory ]; then
  # The session's uncommitted work: notes exported with line breaks flattened.
  python3 - <<'FIXTURE'
import pathlib
board = pathlib.Path("board.py")
text = board.read_text()
text = text.replace('EXPORT_COLUMNS = ["id", "title", "due", "assignee", "done"]',
                    'EXPORT_COLUMNS = ["id", "title", "due", "assignee", "done", "notes"]')
text = text.replace('task["assignee"],\n                         str(task["done"]).lower()])',
                    'task["assignee"],\n                         str(task["done"]).lower(), " ".join(task["notes"].splitlines())])')
board.write_text(text)
FIXTURE
  cat > tests/test_board.py <<'FIXTURE'
import csv
import io
import unittest

from board import add_task, export_csv


def parse(text):
    return list(csv.reader(io.StringIO(text, newline="")))


class ExportTests(unittest.TestCase):
    def test_header_title_and_quoting(self):
        tasks = []
        add_task(tasks, "Check  ladders,\n east site", "2026-09-01", "Ana", "ana@example.com")
        self.assertEqual(parse(export_csv(tasks)), [
            ["id", "title", "due", "assignee", "done", "notes"],
            ["1", "Check ladders, east site", "2026-09-01", "Ana", "false", ""],
        ])

    def test_notes_line_breaks_flattened_in_export_only(self):
        tasks = []
        add_task(tasks, "Stock van", "2026-09-03", "Cy", "cy@example.com", notes="- gloves, size L\r\n- tape")
        self.assertEqual(parse(export_csv(tasks))[1][5], "- gloves, size L - tape")
        self.assertEqual(tasks[0]["notes"], "- gloves, size L\r\n- tape")


if __name__ == "__main__":
    unittest.main()
FIXTURE
  grep -q 'splitlines' board.py || { echo "fixture self-check failed: session edit did not apply" >&2; exit 1; }
  run_tests "session change"
fi

printf 'Fixture ready: %s (%s)\n' "$target" "$mode"
git status --short --branch
