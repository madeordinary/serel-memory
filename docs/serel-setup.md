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
   Hooks: off
   Next: [one action: install, a seed workflow, Kit packs, or resume with /start]
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
   write before approval.
5. **Seed** (Serel Memory, or a pack that needs an initialized bank).
   Continue into the seed workflow in the same session by reading its file
   (`.claude/commands/<name>.md` or `.agents/skills/<name>/SKILL.md`),
   carrying the answers you already have; a new session is only needed to
   call the workflow by name. The workflow still shows its proposals and
   waits for approval before writing any bank file.

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
