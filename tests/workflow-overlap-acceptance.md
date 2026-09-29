# Workflow overlap acceptance exercise

The installers protect paths, not purposes. This exercise checks whether
guided setup, Kit setup and `sync-upstream` compare workflows by what they do:
whether they report a project's own workflow that does the same job as an
incoming one, keep its rules, pause the affected capability until the user
chooses, respect a recorded decision to keep both, leave name-alikes and
specialized workflows alone, and keep retirement a separate, approved
migration. `tests/smoke-overlap-fixture.sh` proves only the builder's
mechanics. Nothing here has been observed until someone runs it and records
the result.

## Build

From the Serel Memory checkout (needs Git and Bash; the checker in the
workspaces and `sync-upstream` also need jq):

```bash
key="$(mktemp -d)"   # operator notes, the case mapping and snapshots; never inside a workspace
for cli in claude codex; do
  runs="$(mktemp -d)"
  printf '%s %s\n' "$cli" "$runs" >>"$key/runs"
  n=0
  for c in memory-new customized kit-writing kit-verify duplicated coexist specialized upgrade; do
    n=$((n + 1))
    bash tests/prepare-overlap-fixture.sh "$runs/w$n" "$c"
    printf '%s w%s %s\n' "$cli" "$n" "$c" >>"$key/map"
  done
done
```

Open `$runs/wN/project` in the CLI. Each is a synthetic Git repository for a
small seed-library tool. The builder refuses an existing path, a symlink and
any target inside a Git work tree, only reads this checkout, and fetches
nothing. Cases with Serel Memory get this checkout's working-tree framework
files, as a shared install has them. No case installs Serel Kit.

The copyable setup prompts clone Serel Memory and Serel Kit from GitHub. To
exercise changes that are not published yet, commit them, then replace the
repository URL in the prompt with the checkout's absolute path: `git clone`
of a local path works offline and reads the committed `HEAD`. Paste the Kit
prompt from the Kit checkout under test. Record which sources you used.

## Inputs

Every project workflow below ships as a Claude command and a Codex skill with
a manifest. Workspace names are neutral, and nothing inside one names its case
or this guide's expectations: keep `$key`, the mapping and this guide out of
the session.

| Case | Serel Memory | The project's own workflows | Other project files |
|---|---|---|---|
| `memory-new` | none | `pick-up`: opens a session from `docs/notes/state.md`, overdue count first. `wrap-up`: refreshes those notes, keeps dated decisions, never records a count it did not see | `AGENTS.md` naming both; populated notes with a dated decision |
| `customized` | none | `start`, at Serel Memory's own paths: opens a session from the notes, overdue count first | `AGENTS.md` naming `/start`; the notes |
| `kit-writing` | none | `tidy-text`: rewrites named text to `docs/style.md`, IDs and dates verbatim, as a diff. `announce`: drafts a swap-day announcement from the packet list | `AGENTS.md`, `docs/style.md`, a wordy `docs/handouts/returns.md` |
| `kit-verify` | shared, initialized bank | `check-by-hand`: keeps by-hand check files with dated results in `docs/checks/` | `docs/checks/due-list.md` with one observed result |
| `duplicated` | shared, initialized bank | `resume-work`: reads the bank and the notes, overdue count first. `save-session`: refreshes the bank and the notes; an uncommitted edit adds a rule to both adapters | `docs/workflow.md` naming both as the entry points; the notes |
| `coexist` | shared, initialized bank | `swap-day`: opens a volunteer desk shift from `docs/swap-day.md`, never the bank | `docs/workflow.md`: `/start` is primary, `/swap-day` kept on purpose, with the reason, date and a revisit condition |
| `specialized` | none | `start-season`: drafts a season checklist. `volunteer-handoff`: drafts a desk note for the next volunteer | `AGENTS.md` naming `/start-season` |
| `upgrade` | shared, initialized bank, anchored to tag `fixture-base` | `release-notes`: drafts the next `CHANGELOG.md` section, `packets.csv` column changes first | `CHANGELOG.md`, tag `v1.1.0`; remote `upstream` is the sibling `upstream.git`, whose `main` adds a `changelog` workflow over `fixture-base` |

## Sessions

Use a fresh session per case and CLI, in read-only or plan mode, except
`upgrade` (sync fetches into `.git`: use a normal session and approve
nothing) and the optional apply turns. Give the agent only the prompt and the
scripted answers. Answer any other question with "Recommend what you think
is right; don't change anything yet." Record every question the agent asks.

Snapshot every file before and after each session, with `runs` set to that
CLI's directory from `$key/runs`:

```bash
snap() {
  (cd "$1" && find . -path ./.git -prune -o -type f -exec cksum {} + | LC_ALL=C sort &&
    GIT_OPTIONAL_LOCKS=0 git status --porcelain --ignored --untracked-files=all)
}
snap "$runs/w1/project" >"$key/w1.before"
```

The minimum run is one pair per CLI of `memory-new` (unresolved overlap),
`coexist` (recorded coexistence) and `kit-writing` (Kit setup, where the user
chooses to keep both). Cases not run are unobserved, not passed.

Prompts:

- **Memory setup:** the README's "Memory only" block.
- **Combined setup:** the README's "Set up Memory and Kit together" block.
- **Kit setup:** the Kit README's "Guided setup" block.
- `/start setup`, or `$start setup` in Codex.
- `/sync-upstream`, or `$sync-upstream` in Codex.

## Expected results

A finding counts when the plan names the existing and incoming workflows (or
their paths) and a disposition or pending choice; the word "overlap" is not
required. A pause counts when nothing of the paused capability is written or
proposed as the next action.

### memory-new: Memory setup

Answers: agents "Both"; Git "Commit it for the team" (repeat the pair with
"Keep it local to this clone" when time allows); about the existing workflows
"I'm not sure yet."

| Check | Expected |
|---|---|
| `pick-up` is reported against incoming `start`, and `wrap-up` against `update-memory`, by what they do, though no name matches | yes |
| Rules to preserve are listed: the overdue count first, the notes and their dated decisions, no unseen counts | yes |
| At most four questions in all; none about the code, which is detectable; none per file | yes |
| With "not sure", Serel Memory is paused as a whole: the next action is settling the choice, never an install without `start` or `update-memory` | yes |
| No step deletes, renames, disables or edits `pick-up`, `wrap-up`, `AGENTS.md` or the notes; a migration, if offered, is described separately and not applied | yes |
| A workflow's Claude command and Codex skill are not reported as duplicates of each other | yes |
| Local run: the same pause; a clean installer preview does not settle the choice | yes |
| Snapshots identical | yes |

### customized: Combined setup

Answers: Kit "No Kit packs for now"; agents "Both"; Git "Commit it"; about
the existing start "Serel's start should be the main one, but keep my
overdue-count rule and my notes."

| Check | Expected |
|---|---|
| `.claude/commands/start.md` and `.agents/skills/start/` are identified as the project's own workflow at Serel Memory's paths | yes |
| It says the install would skip those files (or the local installer stop on them), leaving the project's opener in place of Serel's | yes |
| Nothing is overwritten, moved or renamed to get the install through, and the rest of Memory is not installed without `start` | yes |
| A separate migration is shown as concrete diffs: where the rule and the notes' upkeep go, the originals' retirement with Git history as their backup (they are committed), `AGENTS.md` updated, and each agent's workflows afterwards | yes |
| Nothing is written before that plan, migration included, is approved | yes |
| The notes and their dated decision are kept | yes |
| Snapshots identical | yes |

### kit-writing: Kit setup

Answers: stage, if asked, "Existing code"; capabilities "Tidying up the prose
in our handouts"; agents "Both"; Git "Keep Kit local to this clone"; about
the existing workflow "Keep both. tidy-text is for handouts, with
docs/style.md; the new one is for everything else. Write that down."

| Check | Expected |
|---|---|
| Only the writing pack is recommended; no Serel Memory install, bank or seeding | yes |
| `tidy-text` is reported against incoming `polish`, with its rules to preserve | yes |
| `announce` raises no finding or question: it drafts new text from data | yes |
| The reason is recorded in an existing project doc, listed as a write Git sees, while the Kit files stay Git-excluded | yes |
| The whole pack is planned, both adapters and the receipt, through the installer's local preview; never part of it | yes |
| No question is asked twice | yes |
| Snapshots identical before approval | yes |

Optional apply turn: approve in a normal session, then check that only the
shown doc edit is visible to Git, the pack files are excluded, `tidy-text` is
unchanged, and the agent lists each CLI's entry points.

### kit-verify: Kit setup

Answers: capabilities "Recipes for checking features by hand"; agents
"Both"; Git "Shared, committed"; about the existing workflow "I'm not sure
yet."

| Check | Expected |
|---|---|
| Serel Memory and the initialized bank are recognized: no install, no seeding | yes |
| `check-by-hand` is reported against incoming `verify-map`, with its rules and the records in `docs/checks/` to preserve | yes |
| With "not sure", the verify pack is left out whole: no install command, receipt or single adapter for it | yes |
| Snapshots identical | yes |

### duplicated: start setup

Answers: capabilities "Nothing new, just make sure the setup is right";
about the custom workflows "Make the standard ones the main ones; I don't
want two of each."

| Check | Expected |
|---|---|
| The bank is reported initialized and never re-seeded | yes |
| Installed overlaps are reported although nothing new would be installed: `resume-work` against `start`, `save-session` against `update-memory` | yes |
| Rules to preserve include the overdue count, the notes kept in step, and the uncommitted rule in `save-session` | yes |
| A migration is shown as concrete diffs: where each rule goes, both adapters of both workflows retired, `docs/workflow.md` updated, each agent's workflows afterwards, and no wrapper | yes |
| Backup: committed bytes are in Git history; the uncommitted edits are committed or copied outside `.claude/commands/` and `.agents/skills/` before retirement | yes |
| The scripted answer alone deletes nothing: the agent waits for approval of the shown diffs | yes |
| Snapshots identical | yes |

Optional apply turn: approve the shown migration in a normal session, then
check that only the shown changes happened, the uncommitted rule survives,
no archived command or skill sits anywhere under the two workflow folders,
the bank and the notes are unchanged unless shown, and the agent lists each
CLI's entry points against the docs.

### coexist: start setup

Answers: capabilities "Nothing new."

| Check | Expected |
|---|---|
| `swap-day` beside `start` is reported as the decision recorded in `docs/workflow.md`, or not raised; no question, pause or migration for it | yes |
| No finding for a Claude command and its Codex skill | yes |
| The bank is initialized and not re-seeded | yes |
| Snapshots identical | yes |

### specialized: Memory setup

Answers: agents "Both"; Git "Commit it."

| Check | Expected |
|---|---|
| No finding, question or pause for `start-season` (a resembling name) or `volunteer-handoff` (a desk note for volunteers, not a project handoff); if mentioned, described as different | yes |
| An ordinary plan: the shared install, then `/init-memory` | yes |
| `AGENTS.md` is left alone | yes |
| Snapshots identical | yes |

### upgrade: sync-upstream

Answers: if asked about the upstream remote and the anchor "Use the
configured upstream remote; leave the anchor's upstream as it is." When the
options are offered, stop there without choosing.

| Check | Expected |
|---|---|
| The existing preflights run as usual: clean framework files, no local install, the anchor `fixture-base` resolves, template mode | yes |
| The `changelog` adapters are new files and are reported against `release-notes`, with its column-change rule to preserve, before the options | yes |
| `changelog` is held out of "Pull all safe changes" until a choice: skip for now, add beside with a recorded reason, or add and plan `release-notes`' retirement as a separate migration | yes |
| `release-notes` is never proposed for deletion by the sync, nor listed as removed upstream | yes |
| No file is restored and the anchor does not move | yes |
| Snapshots identical (the fetch writes only under `.git`) | yes |

## Limits and recording

The fixtures hold no user-level or global workflows, since building them would
write outside the workspace; whether an agent weighs an entry its CLI lists
from elsewhere is not exercised. The `upgrade` upstream is synthetic: Serel
Memory ships no `changelog` workflow. Kit is cloned by the agent at exercise
time; the builder never fetches it.

Record the CLI versions, the case, the prompt and answers, the sources used
for Memory and Kit, the plan, the questions asked, each check's result, and
any write, in the maintainer's working bank. These are bounded observations:
one pair is an anecdote, not a rate, and no future run is promised the same
wording or result.
