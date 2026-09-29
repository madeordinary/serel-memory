#!/usr/bin/env bash
# Build a synthetic workspace for the manual exercise in
# tests/workflow-overlap-acceptance.md: how setup and sync treat a project's
# own workflows that do the same job as Serel Memory's or Serel Kit's.
#
# usage: prepare-overlap-fixture.sh <new-directory> <case>
#
#   memory-new   no Serel Memory; the project's own session opener and
#                session-notes workflows, under other names
#   customized   no Serel Memory; the project's own session opener at the
#                paths Serel Memory's start workflow uses
#   kit-writing  no Serel Memory; the project's own prose rewrite workflow and
#                an announcement drafter
#   kit-verify   Serel Memory with an initialized bank; the project's own
#                by-hand check workflow and its records
#   duplicated   Serel Memory with an initialized bank; the project's own
#                session opener and memory refresh installed beside it, one
#                of them with uncommitted edits
#   coexist      Serel Memory with an initialized bank; a brief session opener
#                kept beside start by a decision in docs/workflow.md
#   unrecorded   the same session openers without the coexistence decision
#   specialized  no Serel Memory; workflows whose names or topics resemble
#                Serel Memory's but whose jobs differ
#   upgrade      Serel Memory at a synthetic baseline; a local synthetic
#                upstream whose main adds one workflow; the project's own
#                workflow for the same job
#
# The workspace is <new-directory>/project. The upgrade case also creates the
# bare repository <new-directory>/upstream.git, the workspace's upstream
# remote. Serel Memory's files are copied from this checkout's working tree.
# Nothing is fetched, no Serel Kit file is installed, everything is synthetic,
# and nothing in a workspace names its case or the expected results.
set -euo pipefail
# Any Git transport other than a local path fails: fixture generation never
# touches the network.
export GIT_ALLOW_PROTOCOL=file
root="$(cd "$(dirname "$0")/.." && pwd -P)"
cases="memory-new customized kit-writing kit-verify duplicated coexist unrecorded specialized upgrade"
usage() {
  echo "usage: $0 <new-directory> <case>" >&2
  echo "cases: $cases" >&2
  exit 1
}
[ "$#" -eq 2 ] || usage
out="$1"
fixture_case="$2"
case " $cases " in *" $fixture_case "*) ;; *) usage ;; esac
if [ -e "$out" ] || [ -L "$out" ]; then
  echo "target must not exist" >&2
  exit 1
fi
parent="$(cd "$(dirname "$out")" 2>/dev/null && pwd -P)" ||
  { echo "the target's parent directory must exist" >&2; exit 1; }
if git -C "$parent" rev-parse --git-dir >/dev/null 2>&1; then
  echo "target must be outside any Git work tree (this checkout included)" >&2
  exit 1
fi
out="$parent/$(basename "$out")"
mkdir "$out"
ws="$out/project"
mkdir "$ws"

init_repo() {
  git -c core.hooksPath=/dev/null init -q
  git symbolic-ref HEAD refs/heads/main
  git config user.name "Synthetic acceptance fixture"
  git config user.email "fixture@example.com"
  git config core.hooksPath /dev/null
  git config commit.gpgsign false
}
# Fixed dates keep every build's history metadata identical.
commit() { git add -A && GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2"; }

# Serel Memory's framework files, as a shared install has them.
copy_framework() {
  mkdir -p .claude .agents docs bin
  cp "$root/AGENTS.md" .
  cp -R "$root/.claude/commands" .claude/
  cp -R "$root/.agents/skills" .agents/
  cp -R "$root/hooks" .
  cp "$root/docs/workflow-contract.md" "$root/docs/cross-agent-review.md" "$root/docs/serel-setup.md" docs/
  cp "$root/bin/serel-memory" bin/
}

# workflow <name> <description>: one workflow, body on stdin, written as the
# pair each CLI discovers (a Claude command and a Codex skill) plus a manifest.
workflow() {
  local name="$1" desc="$2" body
  body="$(cat)"
  mkdir -p .claude/commands ".agents/skills/$name/agents"
  printf -- '---\ndescription: "%s"\n---\n\n# /%s\n\n%s\n' "$desc" "$name" "$body" >".claude/commands/$name.md"
  printf -- '---\nname: %s\ndescription: "%s"\n---\n\n# %s\n\n%s\n' "$name" "$desc" "$name" "$body" >".agents/skills/$name/SKILL.md"
  printf 'interface:\n  display_name: "%s"\n  short_description: "%s"\n  default_prompt: "Use %s."\n' \
    "$name" "$desc" "\$$name" >".agents/skills/$name/agents/openai.yaml"
}

product() {
  cat >README.md <<'FIXTURE'
# Seed Swap

Synthetic acceptance data, not a real product. A community seed library lends
packets of seeds and asks for them back after the harvest. `swap.sh` lists the
packets on loan and the ones due back by a date (inclusive).

```bash
./swap.sh list packets.csv
./swap.sh due packets.csv 2026-10-01
```
FIXTURE
  cat >swap.sh <<'FIXTURE'
#!/usr/bin/env bash
# List the seed packets on loan, or those due back by a date (inclusive).
set -euo pipefail
usage="usage: swap.sh list|due <packets.csv> [YYYY-MM-DD]"
cmd="${1:?$usage}"
file="${2:?$usage}"
case "$cmd" in
  list) awk -F, 'NR > 1 { print $1, $2, "due", $4 }' "$file" ;;
  due)
    by="${3:?$usage}"
    awk -F, -v by="$by" 'NR > 1 && $4 <= by { print $1, $2, "due", $4 }' "$file"
    ;;
  *) echo "$usage" >&2; exit 1 ;;
esac
FIXTURE
  chmod +x swap.sh
  cat >packets.csv <<'FIXTURE'
id,variety,borrower,due
SS-0142,Runner bean,B-07,2026-09-28
SS-0157,Calendula,B-12,2026-10-12
SS-0163,Cherry tomato,B-03,2026-10-05
FIXTURE
}

# Notes an existing workflow keeps: populated memory the project already has.
notes() {
  mkdir -p docs/notes
  cat >docs/notes/state.md <<'FIXTURE'
# Session notes

Goal: add a `returned` command that marks a packet as back.
Last change: `due` takes the date to compare against (2026-09-12).
Next step: choose the column for the return date.

## Decided

- 2026-09-05 (maintainer): due dates are inclusive.
FIXTURE
}

# An initialized bank, as an approved seed workflow would leave it.
seed_bank() {
  mkdir -p memory-bank
  cat >memory-bank/projectbrief.md <<'FIXTURE'
# Project Brief

## What

Seed Swap (synthetic acceptance fixture, not a real product): a command-line
tool for a community seed library that lists packets on loan and those due
back.

## Why

Volunteers need the due list on swap days without opening a spreadsheet.
FIXTURE
  cat >memory-bank/productContext.md <<'FIXTURE'
# Product Context

## Users

Volunteers at the swap-day desk, and the one maintainer who keeps the tool.
FIXTURE
  cat >memory-bank/systemPatterns.md <<'FIXTURE'
# System Patterns

## Architecture

One Bash script, `swap.sh`, reads `packets.csv` with awk. Dates are ISO 8601,
so comparing them as strings orders them.
FIXTURE
  cat >memory-bank/techContext.md <<'FIXTURE'
# Tech Context

## Stack

Bash and awk only.

## Run

`./swap.sh list packets.csv` and `./swap.sh due packets.csv <YYYY-MM-DD>`.
FIXTURE
  cat >memory-bank/decisionLog.md <<'FIXTURE'
# Decision Log

## Active decisions

- 2026-09-05: due dates are inclusive; a packet due on the given date is
  listed. User-approved by the maintainer. Result: `swap.sh due` compares
  with `<=`.
FIXTURE
  cat >memory-bank/activeContext.md <<'FIXTURE'
# Active Context

## Current focus

Add a `returned` command that marks a packet as back.

## Next steps

1. Choose the column for the return date.
2. Add the command.

## Open questions

- Should a returned packet stay in `packets.csv`? (Undecided.)
FIXTURE
  cat >memory-bank/progress.md <<'FIXTURE'
# Progress

## Status

Phase: in use at the monthly swap day.

## What works

- `list`, and `due` with inclusive dates.

## What's left to build

- `returned`.
FIXTURE
  printf '%s\n' '# Project Rules & Learnings' '' '- Keep swap.sh dependency-free: Bash and awk only.' >.rules
}

anchor() {
  printf '{"upstream":"madeordinary/serel-memory","ref":"%s","linked":false}\n' "$1" >.serel-memory.json
}

project_agents() {
  cat >AGENTS.md <<'FIXTURE'
# Seed Swap agent notes (synthetic)

- `packets.csv` is exported from the library's spreadsheet: never edit it by
  hand.
- Keep `swap.sh` to Bash and awk.
FIXTURE
}

cd "$ws"
init_repo
product
case "$fixture_case" in
  kit-verify|duplicated|coexist|unrecorded|upgrade) installed=yes ;;
  *) installed=no ;;
esac
if [ "$fixture_case" = upgrade ]; then
  cat >CHANGELOG.md <<'FIXTURE'
# Changelog

## v1.1.0 — 2026-09-12

- `due` takes the date to compare against.

## v1.0.0 — 2026-08-01

- `list` and `due`.
FIXTURE
fi
commit "2026-09-12T10:00:00Z" "Add swap.sh and the packet list"
[ "$fixture_case" != upgrade ] || git tag v1.1.0
if [ "$installed" = yes ]; then
  copy_framework
  seed_bank
  if [ "$fixture_case" = upgrade ]; then anchor fixture-base; else anchor fixture-no-framework-baseline; fi
  commit "2026-09-14T10:00:00Z" "Add Serel Memory and the memory bank"
else
  project_agents
fi

case "$fixture_case" in
  memory-new)
    cat >>AGENTS.md <<'FIXTURE'
- Open each session with `/pick-up` in Claude Code or `$pick-up` in Codex.
- Before you stop, run `/wrap-up` (`$wrap-up`).
FIXTURE
    notes
    workflow pick-up "Resume Seed Swap work from the session notes" <<'FIXTURE'
Resume work on Seed Swap in a new session.

1. Read `docs/notes/state.md`, then run `git log --oneline -5` and `git status`.
2. Run `./swap.sh due packets.csv <today's date>` and report how many packets
   are overdue before anything else: volunteers ask for that number first.
3. Summarize the goal, the last change and the next step from the notes.
4. Ask where to pick up, and wait.
FIXTURE
    workflow wrap-up "Save this session's state to the session notes" <<'FIXTURE'
Before the session ends, bring `docs/notes/state.md` up to date.

1. Read `docs/notes/state.md` and this session's changes (`git status`,
   `git diff`).
2. Rewrite Goal, Last change and Next step. Add any decision the maintainer
   made, with its date, under Decided, and keep the earlier entries.
3. Never record a packet count you did not see from `swap.sh` in this session.
4. Show the diff and wait for approval before writing.
FIXTURE
    ;;
  customized)
    cat >>AGENTS.md <<'FIXTURE'
- Open each session with `/start` in Claude Code or `$start` in Codex.
FIXTURE
    notes
    workflow start "Open a Seed Swap session from the session notes" <<'FIXTURE'
Open a Seed Swap working session.

1. Read `docs/notes/state.md`, then run `git log --oneline -5` and `git status`.
2. Run `./swap.sh due packets.csv <today's date>` and report how many packets
   are overdue before anything else: volunteers ask for that number first.
3. Summarize the goal, the last change and the next step from the notes.
4. Ask where to pick up, and wait.
FIXTURE
    ;;
  kit-writing)
    cat >>AGENTS.md <<'FIXTURE'
- Volunteer handouts live in `docs/handouts/` and follow `docs/style.md`.
FIXTURE
    mkdir -p docs/handouts
    cat >docs/style.md <<'FIXTURE'
# House style for handouts

- Short sentences. One instruction per line.
- Say "packet", never "unit" or "item".
- Dates as 12 October 2026 in prose; packet IDs such as `SS-0142` exactly as
  printed on the label.
- No exclamation marks.
FIXTURE
    cat >docs/handouts/returns.md <<'FIXTURE'
# Returning seeds

In order to facilitate the efficient processing of returned units, it is
requested that all borrowers endeavour to bring back their items on or prior
to the due date which is printed on the label of each and every packet!
Packets like SS-0142 that are returned after the due date will still be
accepted, but please do let a volunteer know at the desk so that the records
can be updated accordingly.
FIXTURE
    workflow tidy-text "Rewrite named text to the library's house style, as a diff" <<'FIXTURE'
Rewrite the text the user names (a file, a section, or pasted text) so a
first-time volunteer can follow it.

- Follow every rule in `docs/style.md`.
- Keep packet IDs (like `SS-0142`), dates and commands exactly as written.
- Keep the meaning; never add a claim the text did not make.
- Show the rewrite as a diff. Write nothing unless the user asks.
FIXTURE
    workflow announce "Draft the swap-day announcement from the packet list" <<'FIXTURE'
Draft the announcement for the next swap day, for the library's mailing list.

1. Ask for the swap day's date and place if they were not given.
2. Run `./swap.sh due packets.csv <that date>` and list the varieties coming
   back, without borrower codes.
3. Draft a short announcement: date, place, what to bring back, and what may
   be available. Follow `docs/style.md`.
4. Show the draft. Do not send or save it.
FIXTURE
    ;;
  kit-verify)
    mkdir -p docs/checks
    cat >docs/checks/due-list.md <<'FIXTURE'
# Due list

Launch: nothing to start; run from the repository root.

Steps:

1. Run `./swap.sh due packets.csv 2026-10-05`.

Look for: `SS-0142` and `SS-0163` listed, `SS-0157` absent.

## Results

- 2026-09-20, maintainer: `SS-0142` and `SS-0163` listed, `SS-0157` absent.
  macOS 14, Bash 3.2.
FIXTURE
    workflow check-by-hand "Write or refresh the by-hand check for a feature" <<'FIXTURE'
Keep one file per feature in `docs/checks/<feature>.md`: how to check it by
hand, and what someone saw when they did.

1. Read the feature's existing check file, if any, and `README.md`.
2. Write Launch, Steps and Look for from commands that exist in the repo.
3. Under Results, add only what someone actually observed, newest first, with
   the date and who ran it. Keep older results as they are.
4. Show the diff and wait for approval before writing.
FIXTURE
    ;;
  duplicated)
    notes
    cat >docs/workflow.md <<'FIXTURE'
# How we work (synthetic)

- Open each session with `/resume-work` (Codex: `$resume-work`).
- Close each session with `/save-session` (`$save-session`).
- `packets.csv` comes from the library's spreadsheet export: never edit it by
  hand.
FIXTURE
    workflow resume-work "Resume Seed Swap work" <<'FIXTURE'
Resume work in a new session.

1. Read the files in `memory-bank/`, then `docs/notes/state.md`.
2. Run `./swap.sh due packets.csv <today's date>` and report how many packets
   are overdue before anything else.
3. Summarize the current focus and next steps, and ask where to pick up.
FIXTURE
    workflow save-session "Save this session to the memory bank and the session notes" <<'FIXTURE'
Before the session ends:

1. Update `memory-bank/activeContext.md` and `memory-bank/progress.md` from
   this session's work.
2. Update `docs/notes/state.md` to match: volunteers read it.
3. Show the diffs and wait for approval before writing.
FIXTURE
    ;;
  coexist|unrecorded)
    cat >docs/workflow.md <<'FIXTURE'
# How we work (synthetic)

Both session openers read the project bank and recent Git context.
FIXTURE
    if [ "$fixture_case" = coexist ]; then
      cat >>docs/workflow.md <<'FIXTURE'

## Entry points

The maintainer approved keeping both on 2026-08-30: `/start` (Codex:
`$start`) is primary for full project orientation; `/resume-brief` (Codex:
`$resume-brief`) is primary when the maintainer asks for a short development
session summary. They do the same orientation job at different detail levels.
Keep both with that choice; revisit if their reading or writing behavior changes.
FIXTURE
    fi
    workflow resume-brief "Resume a project development session with a brief summary" <<'FIXTURE'
Open a development session from the project's memory and Git context.

1. Read the core files in `memory-bank/` and `.rules`.
2. Run `git status` and `git log --oneline -3`.
3. Summarize the current focus, completed work and next step in three bullets.
4. Ask where to pick up and wait. Write nothing during orientation.
FIXTURE
    ;;
  specialized)
    cat >>AGENTS.md <<'FIXTURE'
- Each January, run `/start-season` (`$start-season`).
FIXTURE
    workflow start-season "Prepare the opening checklist for a new growing season" <<'FIXTURE'
Once a year, prepare the checklist for the new growing season.

1. Run `./swap.sh list packets.csv` and note the varieties with no packet on
   loan.
2. Draft `docs/seasons/<year>.md`: varieties to restock, sowing reminders by
   month, and the swap-day dates the user gives you.
3. Show the draft and wait for approval before writing. Never edit
   `packets.csv`.
FIXTURE
    workflow volunteer-handoff "Write the note for the next swap-day desk volunteer" <<'FIXTURE'
At the end of a desk shift, write the note the next volunteer reads.

1. Run `./swap.sh list packets.csv`.
2. Ask the volunteer what happened on the shift: returns taken, questions
   left open, where the cash box and keys are.
3. Draft `docs/desk-notes/<date>.md` in plain words: packets still out, open
   questions, keys and cash box. No borrower codes.
4. Show the draft and wait for approval before writing.
FIXTURE
    ;;
  upgrade)
    workflow release-notes "Draft release notes for the next Seed Swap release" <<'FIXTURE'
Draft the next section of `CHANGELOG.md`.

1. List the commits since the newest `v*` tag.
2. Group them under Added, Changed and Fixed.
3. If the columns of `packets.csv` changed, say so first and name the new
   columns: the library's spreadsheet export must match them.
4. Show the diff and wait for approval before writing.
FIXTURE
    ;;
esac
commit "2026-09-15T10:00:00Z" "Add the project's own workflows and notes"

if [ "$fixture_case" = duplicated ]; then
  # The maintainer's latest rule, not committed yet: Git history does not hold it.
  for f in .claude/commands/save-session.md .agents/skills/save-session/SKILL.md; do
    cat >>"$f" <<'FIXTURE'

Never record a packet count you did not see from `swap.sh` in this session.
FIXTURE
  done
fi

if [ "$fixture_case" = upgrade ]; then
  # A synthetic upstream: the framework this workspace installed, tagged as
  # its anchor, then one commit that adds a workflow.
  stage="$out/stage"
  mkdir "$stage"
  (
    cd "$stage"
    init_repo
    copy_framework
    commit "2026-09-10T10:00:00Z" "Framework baseline"
    git tag fixture-base
    workflow changelog "Draft the next CHANGELOG.md section from commits since the last release" <<'FIXTURE'
Draft the next `CHANGELOG.md` section from the work since the last release.

1. Find the newest release tag and list the commits since it.
2. Group the changes under Added, Changed and Fixed, in plain words, and leave
   out changes users will not notice.
3. Show the new section as a diff at the top of `CHANGELOG.md` and wait for
   approval before writing.
FIXTURE
    commit "2026-09-20T10:00:00Z" "Add the changelog workflow"
  )
  git clone -q --bare "$stage" "$out/upstream.git"
  rm -rf "$stage"
  git remote add upstream "$out/upstream.git"
fi

printf 'Fixture ready: %s\n' "$ws"
git status --short --branch
