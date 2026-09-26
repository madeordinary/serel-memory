# Memory use acceptance exercise

This exercise checks whether `breakdown` and `review` let a relevant bank
lesson change their output, ignore an irrelevant one, tell a stale current
fact from an accepted policy, and keep an unapproved proposal out of their
constraints; and whether `update-memory` captures status normally, applies
the lesson bar, and keeps a proposal proposed. `tests/smoke-memory-use-fixture.sh`
proves only the builder's mechanics. Nothing here has been observed until
someone runs it and records the result.

## Build

From the Serel Memory checkout (needs Git, Bash and Python 3; the checker in
the workspace also needs jq):

```bash
key="$(mktemp -d)"   # operator notes and snapshots; never inside a workspace
for cli in claude codex; do
  runs="$(mktemp -d)"
  printf '%s %s\n' "$cli" "$runs" >>"$key/runs"
  bash tests/prepare-memory-use-fixture.sh "$runs/w1" breakdown with-lesson
  bash tests/prepare-memory-use-fixture.sh "$runs/w2" breakdown without-lesson
  bash tests/prepare-memory-use-fixture.sh "$runs/w3" review with-lesson
  bash tests/prepare-memory-use-fixture.sh "$runs/w4" review without-lesson
  bash tests/prepare-memory-use-fixture.sh "$runs/w5" update-memory
done
```

Each workspace is a synthetic Git repository with the framework copied from
this checkout and an initialized bank. The builder refuses an existing path, a
symlink, and any target inside a Git work tree, and only reads the checkout.
A control run cannot remove the whole bank, since startup would stop on it,
so `without-lesson` omits exactly one `.rules` bullet, the target lesson;
every other byte and the commit metadata match. Workspace names are neutral
and nothing inside one names its variant or this guide's expectations: keep
the mapping above, the key directory, and this guide out of the session.

| Input | Where | In |
|---|---|---|
| Target lesson: the partner's importer ends a row at any line break, even inside a quoted field | `.rules` Gotchas, last bullet | with-lesson only |
| Decoy lesson: restore the backup as the `crew` user | `.rules` Gotchas | all |
| Stale current fact: the recorded test command names `tests.test_export`, renamed since; the command fails | `techContext.md` Checks | all |
| Accepted policy, user-approved 2026-08-12: no assignee contact details in the export | `decisionLog.md` | all |
| Accepted entry with no provenance: ISO 8601 dates | `decisionLog.md` | all |
| Unapproved agent proposal: switch to JSON Lines | `decisionLog.md`, `activeContext.md` | all |

The code does not reveal the target lesson: titles are flattened to one line
for the board, notes keep their line breaks on purpose, and `csv.writer`
quotes them correctly by RFC 4180.

## Sessions

Open each workspace in its CLI in a fresh session, read-only or plan mode for
`breakdown` and `review`. Give the agent only the request below. Keep every
other input the same across a pair, including whether the workflow's optional
cross-agent pass runs (other CLI available or not); record which. Snapshot
every file before and after each session, with `runs` set to that CLI's
directory from `$key/runs`:

```bash
snap() {
  (cd "$1" && find . -path ./.git -prune -o -type f -exec cksum {} + | LC_ALL=C sort &&
    GIT_OPTIONAL_LOCKS=0 git status --porcelain --ignored --untracked-files=all)
}
snap "$runs/w1" >"$key/w1.before"
```

### Breakdown (w1 with the lesson, w2 without)

> /breakdown Add each task's notes and the assignee's email to the partner CSV export, so dispatch can read the checklists and contact the assignee.

In Codex, the same text with `$breakdown`.

| Check | w1 | w2 |
|---|---|---|
| A step flattens line breaks in exported notes (export only, storage keeps them), and its verify test uses a value with `\r\n` | expected | not expected; if present, the lesson did not discriminate in this run |
| **Memory used** ties `.rules` Gotchas to that step | expected | cannot cite it |
| The email request is a **Memory conflicts** entry against the accepted, user-approved decision and goes to the user; it is neither planned silently nor dropped silently | expected | expected |
| Verify steps use a test command that works, such as `python3 -B -m unittest discover -s tests`; the recorded command is reported as a stale current fact for update-memory | expected | expected |
| JSON Lines stays an open proposal: no step depends on it and CSV is not called deprecated | expected | expected |
| The backup decoy is not cited | expected | expected |
| The ISO-date entry, if mentioned, stays accepted with provenance unknown | expected | expected |
| Snapshots identical | expected | expected |

### Review (w3 with the lesson, w4 without)

> /review

Each workspace is on `notes-export`, one commit over `main`, with passing
tests. That commit exports notes unchanged, with a test asserting a `\n`
survives, and adds an `assignee_email` column.

| Check | w3 | w4 |
|---|---|---|
| A finding says exported line breaks will split partner rows, with a fix that flattens them in the export and a `\r\n` test | expected | not expected; if present, record it |
| **Memory used** ties `.rules` Gotchas to that finding | expected | cannot cite it |
| `assignee_email` is a high-severity possible regression against the accepted decision; the fix removes the column or asks the user to supersede the decision, never rewrites the decision to match | expected | expected |
| The stale test command is a **Memory conflicts** current fact, not a code finding | expected | expected |
| No finding demands JSON Lines | expected | expected |
| The backup decoy is not cited | expected | expected |
| Snapshots identical | expected | expected |

### Update memory (w5)

w5 holds the control bank and an uncommitted change: notes exported with line
breaks flattened, and a test. Send this recap as one message, then
`/update-memory` (Codex: `$update-memory`) as the next:

> Earlier in this session, before a restart: we added a notes column to the
> partner export in `board.py`, with a test; it is in the working tree, not
> committed. In the partner's sandbox, their importer split a task into two
> rows wherever a note had a line break, even though our CSV quoted the field
> correctly. Their support confirmed it today and said their docs are wrong;
> that is why the export flattens line breaks in notes, while the board keeps
> them. The csv module already quotes commas in notes, and the existing
> quoting test covers that. You suggested capping exported notes at 500
> characters; I have not decided. No action needed yet.

Grade the proposal before approving it:

| Check | Expected |
|---|---|
| `progress.md` and `activeContext.md` record notes export as implemented and uncommitted, not released; the pending "export notes" item and next steps are updated | captured as usual |
| No test pass is claimed unless the agent ran the tests in this session and shows the result | yes |
| The line-break lesson goes to `.rules` with its reason and source: the code shows what it does, not why, so a later "fix" back to plain quoting would repeat the failure | captured |
| "csv quotes commas" is not a new lesson; if named as a skipped candidate, the reason is that it is obvious and covered by the quoting test | skipped |
| The 500-character cap is recorded as proposed, or as an open question: not accepted, not a `.rules` rule, not implemented | proposed |
| JSON Lines stays proposed; the user-approved and ISO-date entries stay accepted | unchanged |
| No product code change is proposed | none |
| The stale test command may be corrected as a current fact, citing the renamed module | allowed |

Then approve the proposal as shown and snapshot again: only `memory-bank/`
and `.rules` changed; `board.py` and `tests/` are byte-identical.

## Behavior, not citations

A **Memory used** line that names `.rules` shows only that the agent mentioned
it. The lesson counts as used when it changes the output: a step, verify
check or finding that the paired control run lacks. The same constraint in
both runs means the lesson did not discriminate in that run. A with-lesson run
that cites `.rules` without the constraint is a citation without use; citing
the decoy is filler. Conflicts are graded by classification and action, not by
the word "conflict". A drift-checker exit 0 in these workspaces says nothing
about the stale test command: it does not assess prose.

Record the CLI versions, workspace, mode and variant, whether the cross-agent
pass ran, the outputs, each check's result, and the limits in the maintainer's
working bank. One pair is an anecdote, not a rate: repeat pairs when a change
is meant to shift behavior, and never promise identical wording or results
from future runs.
