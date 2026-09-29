# Guided setup

Setup is a short conversation that ends in a plan you approve. The agent looks
before it asks, recommends the smallest setup that fits, and shows every path
it will write and whether Git will see it. Nothing is written in your project
until you approve that plan. Filling the memory bank comes after, through the
usual seed workflow and its own approval step.

Status: unreleased. This guide, `/start setup` and `install.sh --local` exist
only in a Serel Memory checkout that contains this file; no release includes
them yet, and v0.6.0 does not.

## The flow

1. **Look first.** Read without writing, and resolve the scope before anything
   else: in a repository whose `.serel-memory.json` lists `scopes`, the scope
   is `--scope <path>`, else the current directory's project, else the root
   ("Resolving scope" in `docs/workflow-contract.md`). Then, for that scope:
   - Product code: manifests and source folders of the project itself. Serel
     Memory's own files are not product code: its workflows in
     `.claude/commands/` and `.agents/skills/`, `hooks/`, `bin/serel-memory`,
     its framework docs, the bank templates, `.rules`, the anchor, and the
     `tests/`, `.github/` CI and project metadata a degit copy brings along.
     Code in another folder of a monorepo is not the selected project's
     implementation.
   - A PRD, brief or spec (`docs/`, names containing `prd`, `brief`, `spec`,
     `requirements`).
   - Instruction files (`AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`,
     `CLAUDE.local.md`) and what `.claude/` and `.agents/` already hold.
   - Workflows by purpose: what each agent would reach for to do the jobs
     this setup adds, whatever the names, installed ones included (see
     "Overlapping workflows").
   - Whether Serel Memory is installed and how: a tracked
     `.serel-memory.json` is shared; a Git-excluded anchor, or one of the
     files only Serel Memory installs, means local (the test in "Setup
     routing" in `docs/workflow-contract.md`). A local install holds the root
     bank only: at a project scope, stop here (see "Local install"). Then the
     bank's state (below).
   - Whether Serel Kit is installed (a `.serel-kit.json` receipt).
2. **Ask only what you could not detect**, one short question per message,
   waiting for each answer: at most four in total, and none about anything
   already detected or already said.
   - Stage: a rough idea, a spec with no code yet, existing code, or code plus
     a spec?
   - Capabilities: Serel Memory, Serel Kit packs (`writing`, `verify`), or
     both? Packs keep Kit's own requirements: `writing` needs no bank and no
     seeding; `verify` needs Serel Memory to install and an initialized bank
     to run.
   - Agents: Claude Code, Codex, or both?
   - Git: share it with everyone who clones the repository (committed), or
     keep it in this clone only (Git-excluded)? Memory and Kit can differ.
     When Serel Memory is already installed, its storage is settled.
3. **Recommend the smallest supported setup** as one plan:

   ```text
   SETUP PLAN
   Scope: [`.` or the project root]
   Stage: [idea / spec, no code / code / code + spec] (evidence: [paths])
   Bank: [none needed / missing / blank / partial / initialized]
   Capabilities: [Serel Memory / Kit: packs / both]
   Requires: [none / verify: install Serel Memory, seed the bank]
   Agents: [Claude Code / Codex / both] (entry point: /start / $start)
   Storage: Memory [shared / local / installed: shared or local]; Kit [shared / local / none]
   Writes: [paths, or the installers' previews] (visible to Git: [yes / no])
   Left alone: [existing AGENTS.md, CLAUDE.md, other files]
   Overlaps: [none found / existing path ↔ incoming path: rules to preserve; primary: [entry]; kept both, recorded in [doc] / migrate, diffs shown / paused]
   Hooks: off
   Next: [one action: resolve an overlap / review migration diffs / install / seed / add Kit packs / resume with /start]
   ```

   Defaults: Serel Memory only, hooks off, and both adapters (each tool
   ignores the other's files). The agent answer picks the entry point and the
   instruction-file notes, not the payload. A chosen pack's requirements are
   never met silently: when `verify` is chosen and Serel Memory is missing or
   the bank is not initialized, `Requires` names the install or seed workflow
   it needs, and each keeps its own approval.
4. **Approve, then install.** Wait for approval of that plan, unless the user
   has already told you to go ahead with it; never ask again for an answer or
   an approval already given. For a local install, the installer's preview is
   the list of writes, and `--apply` runs only after approval. Cloning Serel
   Memory or Serel Kit into a temporary folder outside the project is the only
   write before approval. An unresolved overlap pauses only the capability it
   affects; after the approved writes, check the entry points as described in
   "Overlapping workflows".
5. **Seed** (Serel Memory, or a pack that needs an initialized bank).
   Continue into the seed workflow in the same session by reading its file
   (`.claude/commands/<name>.md` or `.agents/skills/<name>/SKILL.md`),
   carrying the answers you already have; a new session is only needed to
   call the workflow by name. The workflow still shows its proposals and
   waits for approval before writing any bank file.

## Overlapping workflows

The installers protect paths, not purposes. A project's own `/kickoff` that
opens a session installs cleanly beside Serel Memory's `/start`, and then the
two compete. So setup compares workflows by what they do. This is an
agent-guided review, not a guarantee that no duplicate remains; the
installers still protect only paths.

**What to compare.** For each agent, the workflows it would discover in this
project, including `.claude/commands/`, `.claude/skills/` and `.agents/skills/`
when present. Use the CLI's surfaced inventory to establish what it actually
discovers; include installed Serel Memory and Kit workflows, plus any user-level or
global entry the CLI already lists in this session when it does the same job.
Do not search private or global folders beyond that, and never edit them.
Compare them with what the plan would add, Serel Memory's workflows or the
chosen Kit packs, by purpose, trigger and behavior (what each reads, writes
and stops for), whatever their names or prefixes. There are two kinds of
finding:

- **Overlap:** an existing workflow an agent could pick for the same job as an
  incoming one, such as `/kickoff` beside `/start`, or a project's own
  manual-check recipe workflow beside Kit's `/verify-map`.
- **Same-path customization:** an existing file at an incoming path, whether
  the project's own workflow or an edited copy. The shared install's
  `rsync --ignore-existing` skips it and the local installer stops on it; it
  is never overwritten, and its project rules are listed to preserve.

These are not findings: a resembling name alone (`/start-server` that
launches a dev server); a Claude command and a Codex skill for the same
workflow, the intended two-agent pair alone; and a
specialized workflow that shares a topic but does a different job or serves a
different audience (a customer release email beside `/weekly-update`). When
unsure, state the difference instead of calling it a duplicate.

**In the plan.** Each finding goes on the plan's `Overlaps` line: the existing
and incoming paths, the custom rules to preserve, the selected primary entry
point, and a disposition: keep both with a recorded reason, make one primary
through a migration (below), or pause the incoming capability. Settle it
inside setup's existing questions and approval: a disposition already given
is not asked again; one still needed is asked within the four questions, or
offered as choices in the plan, whose approval settles it; no file is
approved on its own. An unresolved overlap pauses the whole affected unit,
all of Serel Memory or one Kit pack, while unaffected choices go ahead. Never
list installation as the next action for an unresolved unit: name the pending
choice or migration review instead. Never install it minus the overlapping
file, or one adapter of a pack without the other; never forge an anchor or
receipt to hide an incomplete install or customizations. Follow the documented
install procedure for truthful metadata.
Never move, rename or overwrite a file merely to bypass a collision check.

**Keeping both.** When the user chooses coexistence, record which workflow is
primary for what, and why, in the project's existing workflow or instruction
doc (`AGENTS.md`, or wherever it already describes its workflows). That edit
is one of the plan's `Writes`, with its Git visibility: a tracked doc beside a
local install is a write Git sees. Later runs respect the record while it
still applies, and raise the finding again when it no longer does (the
workflows or the recorded reason changed).

**Migration.** Setup detects and reports; it does not consolidate. Making one
workflow primary and retiring another is a migration, described separately
as concrete diffs: which custom rules move where; which files are retired;
every reference updated (instruction files, docs, other workflows); where the
original bytes are kept; and each agent's workflows afterwards. It needs
explicit authorization, which the approved plan can carry when it shows those
diffs. A request to install or set up authorizes no deletion or disabling.
Populated memory, decisions and recorded authorizations stay as they are,
including notes a custom workflow maintains. Before retiring an original,
make sure its content survives: Git history holds only committed bytes, so
back up uncommitted edits and untracked or Git-excluded files first. Keep
backups outside every discovered workflow directory, including
`.claude/commands/`, `.claude/skills/` and `.agents/skills/`: an archived
command or skill must not remain an active entry point. Check nested folders
as well. Add no wrapper or alias workflow unless the user asks for
one. Retiring a project's file at an incoming path through an approved
migration, with its backup, can resolve a same-path customization. The
installer then runs unchanged.

**Reruns and updates.** `/start setup` and any rerun of setup review the
workflows already installed, even when nothing new would be added: a custom
`/kickoff` installed beside `/start` is reported like an incoming one. Left
unresolved, it stays reported and nothing changes; resolving it is a recorded
coexistence or a migration. `sync-upstream` applies the same review to new and changed workflows before
offering its options, since an update can add workflows too.

**After.** Once an approved setup or migration is applied, list each agent's
workflows again and check that the selected entry points are the ones
installed and that the instruction files and docs name them.

## Bank states and seed workflows

Check each of the seven core files in the resolved scope's bank:

| Bank | What happens |
|------|--------------|
| missing, or every file empty or template-only (blank) | install if needed, then seed by stage |
| partial: some files have real content | the same seed workflow fills only the files that are missing, empty or template-only; files with real content are kept as they are and read as given |
| initialized: every file has real content | never re-seeded: resume with `/start`, correct with `/update-memory` |

| Stage | Seed workflow |
|-------|---------------|
| A rough idea | `/discover` / `$discover` |
| A spec, no code yet | `/from-prd <path>` / `$from-prd <path>` |
| Existing code | `/init-memory` / `$init-memory` |
| Code plus a spec | `/init-memory` / `$init-memory`, naming the spec |

For code plus a spec, the code is inspected first and describes what exists.
The spec supplies intent and planned scope, labeled as planned; a spec
requirement is never recorded as working without evidence in the code.

In a repository with scoped banks, setup seeds one bank per invocation: pass
`--scope <path>` to the seed workflow. Installation itself stays at the
repository root. Project banks need a shared install; a local install seeds
the root bank only (see "Local install").

`/start setup` (or `$start setup`) runs this flow inside an installed project,
whatever the bank's state: installation is skipped, choosing capabilities is
not, so it can add Kit packs beside an initialized bank without touching it.
Choosing only Kit packs beside a blank or partial bank still follows their
requirements: `writing` leaves the bank as it is, `verify` puts the seed
workflow in the plan. Plain `/start` enters it on its own when the bank is
missing or blank, and offers to fill a partial bank's blank files.

## Shared install (committed)

Use the README's [Install](../README.md#install) commands. The files become
ordinary project files: review them and commit them. Updates come through
`/sync-upstream`.

Those commands are pinned to v0.6.0, which predates this guide. The workflows
they install have no `/start setup`, no code-plus-spec routing and no
partial-bank handling, and `docs/serel-setup.md` is not among the files; do
not report any of that as installed. Continue in the same session instead:
run the chosen seed workflow from the installed files and carry this guide's
answers and rules into it (the code before the spec, the spec as planned
intent, a partial bank's real content kept as it is).

## Local install (Git-excluded)

For a repository where you do not want to commit Serel Memory — someone
else's project, or a team that has not adopted it. Run it from a clone of
Serel Memory that contains this guide, outside your project:

```bash
git clone https://github.com/madeordinary/serel-memory.git /tmp/serel-memory
bash /tmp/serel-memory/install.sh /path/to/your-project --local          # preview
bash /tmp/serel-memory/install.sh /path/to/your-project --local --apply  # install
```

What it does, in this order:

1. Checks everything before writing: the target is the root of a git work
   tree; no destination, or folder on the way, is tracked under any
   capitalization (a tracked `.RULES` counts as `.rules`), a symlink, or
   inside a nested repository; no existing name differs from its destination
   only in case; no existing file differs from the one it would copy; no
   ignore rule re-includes a destination or the `memory-bank/` folder itself
   (ignoring each template is not enough: files added there later must stay
   out of Git too). Any problem stops the run with
   nothing written. It never untracks anything, so a tracked path cannot be
   made local.
2. Adds exact lines to the repository's `info/exclude`, the file Git itself
   resolves (in a linked worktree it is shared by every worktree of the
   repository; the files are not). Each framework file gets its own line;
   `/memory-bank/`, `/.rules` and `/.serel-memory.json` are the memory the
   project owns. It never excludes `.claude/`, `.agents/`, `docs/` or
   `hooks/` as a whole, so your own files there stay visible.
3. Confirms Git now ignores every destination and the `memory-bank/`
   folder, then copies the files and writes the anchor, then checks again,
   under any capitalization, that nothing it installed is tracked or visible
   and that the created `memory-bank/` folder itself is ignored. An ordinary
   failure undoes the run, exclude lines included.

It copies only the framework (the paths `sync-upstream` updates, listed
below), the seven bank templates and `.rules`, and writes the anchor. It never
copies tests, CI, research notes, the README or maintainer data, and never
registers hooks. An existing `AGENTS.md` (in any capitalization) is left
alone and not excluded; start sessions with `/start` or `$start`. When there
is none, a local `AGENTS.md` is installed and excluded.

A local install holds the root bank only. It excludes the root
`memory-bank/` and `.rules`; scoped project banks are not supported locally,
and listing `scopes` in the anchor later does not extend the exclusions, so a
project bank would be visible to Git. After resolving the scope, these stop
at a project scope in a local install, before any plan or write:
`/start setup`, plain `/start` on a missing, blank or partial project bank,
and `/discover`, `/from-prd` or `/init-memory` invoked directly. They leave existing
files, exclusions and instruction files as they are, and offer the root bank
(`--scope .`) or a shared install, where scoped banks work.

Running it again is safe: files it installed, its local `AGENTS.md`, and your
bank, `.rules` and anchor are kept as they are. It never overwrites, so a
framework file you edited, or a newer checkout, stops the run. Updating a
local install is not supported yet. `/sync-upstream` stops while any of
Serel Memory's own framework files is Git-excluded, even if the anchor's own
line is removed, and `bin/serel-memory check` says in an `INFO` line that it
did not compare them against a baseline: Git cannot see their bytes.

The anchor records the checkout honestly: a clean checkout of a release tag
(`vMAJOR.MINOR.PATCH`, optionally `-prerelease`) is written as that tag; any
other tag name, or an untagged commit, as the commit SHA; uncommitted changes
in the payload as the commit SHA with `"linked": true` (exact version
unknown). It always names `madeordinary/serel-memory`; edit `upstream` if you
installed from a fork.

Limits, plainly: the files live in this clone only. Git does not back them
up; `git clean -x` or `-X` deletes them, and `git add -f` can still commit
them. Workflows that write outside the bank (`/handoff`, `/decision-log`
ADRs, `/retro`, `/runbook`) and hook registration create ordinary files that
Git shows. This keeps files out of commits; it is not a security boundary.

There is no uninstaller. To remove a local install by hand, first copy
`memory-bank/`, `.rules` and `.serel-memory.json` somewhere safe if you want
to keep the memory. Then delete the installed files, and in `info/exclude`
only their exact lines: `/<path>` for each file it installed, `/memory-bank/`,
`/.rules` and `/.serel-memory.json`. Keep every other line, including entries
another tool added after the installer's comment.

## Who owns what

| Path | Owner | Shared install | Local install |
|------|-------|----------------|---------------|
| `.claude/commands/`, `.agents/skills/` (Memory's workflows), `docs/workflow-contract.md`, `docs/cross-agent-review.md`, `docs/serel-setup.md`, `hooks/`, `bin/serel-memory` | Serel Memory framework; `sync-upstream` updates them | committed | excluded, one line per file |
| `AGENTS.md` | Serel Memory framework, synced; a project's existing file is never replaced | committed | installed and excluded only when absent |
| `memory-bank/`, `.rules` | the project (templates are copied once, never synced) | committed | excluded at the root only; `/memory-bank/` as a whole |
| `.serel-memory.json` | the project (records the starting version) | committed | excluded |
| `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md` | the project; Serel Memory never creates them | — | — |
| Kit pack files in `.claude/commands/`, `.agents/skills/`, and `.serel-kit.json` | Serel Kit | committed | excluded by Kit's own local mode, never by Serel Memory |

Serel Memory needs Bash and Git. The drift checker, scoped banks and the hook
enable scripts also use `jq`. Hooks are optional and off until you run their
enable scripts, which write settings files Git will see. Serel Kit's
installer needs `jq` as well as Bash and Git.

## Serel Kit

[Serel Kit](https://github.com/madeordinary/serel-kit) is optional: packs
such as `writing` and `verify`, installed by Kit's own installer with a
`.serel-kit.json` receipt. Serel Memory owns the bank, `.rules` and the
anchor; each installer writes only its own files, and Serel Memory never adds,
changes or removes Kit's exclusions.

Kit has its own local mode: its installer previews with `--local` and installs
with `--local --apply`, and the receipt keeps that mode for later pack
additions and upgrades. Each tool's storage is chosen on its own:

- Memory local, Kit shared: install Memory with `install.sh --local`, then
  the selected Kit packs with Kit's ordinary installer and commit them. Kit
  stays shared; it is not inferred local from Memory.
- Memory shared, Kit local: install Memory with the README's commands, then
  Kit with `--local`. `/sync-upstream` and the drift checker's baseline
  comparison work as usual: their local-install check counts only Serel
  Memory's own Git-excluded files, not Kit's.
- Kit only: install Kit shared or local. With `writing` alone there is no
  bank to seed; `verify` adds Serel Memory to the plan, installed before the
  pack if missing and its bank seeded before the pack runs.

Serel Memory's installer never turns a tracked file into a local one: a
tracked destination stops it.
