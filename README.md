# Serel Memory

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Works with Claude Code + Codex](https://img.shields.io/badge/works%20with-Claude%20Code%20%2B%20Codex-5436DA) ![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

A portable memory bank and workflow kit for AI coding agents. Works with Claude Code and Codex out of the box. Formerly known as **Basecamp**.

Your project's memory lives in version-controlled markdown you can read, diff, and review — not a proprietary store that gets deprecated, stays on one machine, or locks you to a single IDE.

## Quickstart

```bash
npx degit madeordinary/serel-memory#v0.1.0 my-project
cd my-project
git init
printf '{ "upstream": "madeordinary/serel-memory", "ref": "v0.1.0", "linked": false }\n' > .basecamp.json
```

(The last line records which Serel Memory version you started from — `sync-upstream` uses
it later to show you exactly what changed upstream since. Skip it and `sync-upstream`
will offer to reconstruct it.)

> **Renamed from Basecamp:** `.basecamp.json` and `BASECAMP_HOOKS=off`
> remain supported for every v0.x release. New installs use the canonical
> `madeordinary/serel-memory` upstream. See the
> [compatibility guide](docs/basecamp-compatibility.md).

Open the project in Claude Code or Codex, then seed the memory bank based on what you have:

| You have… | Run (Claude / Codex) |
|-----------|----------------------|
| Existing code | `/init-memory` / `$init-memory` |
| A PRD or brief | `/from-prd docs/prd.md` / `$from-prd docs/prd.md` |
| Just a rough idea | `/discover` / `$discover` |
| A clear idea in your head | paste it into `memory-bank/projectbrief.md` |

Then run `/start` (or `$start`) — the agent reads the bank and asks where to pick up. That's the loop: seed once, `/start` every session, `/update-memory` before you stop.

> New here? Read [The problem](#the-problem) and [The shape](#the-shape) below. Already sold? The [full install options](#install) (existing projects, PRDs, pinning) are further down.

## The problem

AI coding agents lose their memory between sessions. Every new conversation starts from zero. The agent doesn't remember what you're building, what you decided last week, which patterns you've already rejected, or what's currently broken.

The usual fix is to dump a paragraph of context into every prompt. That works until you forget something, or the context grows beyond what fits, or you switch tools and have to do it all again.

Serel Memory is the other fix: a small, opinionated directory of markdown files the agent reads at the start of every session, so context doesn't depend on your memory.

## What makes it different

Memory banks aren't new — Serel Memory's own is adapted from [Cline's](https://github.com/nickbaumann98/cline_docs), and says so. What you can't get elsewhere is the engineering around the bank:

- **Dual-CLI parity that's enforced, not promised.** Every workflow has a native Claude Code command *and* a native Codex skill — 17 of each, and CI fails if either side of a pair goes missing. Not a Claude tool with a Codex shim bolted on.
- **Cross-agent second opinions.** Claude can shell out to Codex to review a plan, and vice versa — with a documented loop policy, and an honestly-labeled self-critique fallback when the other CLI isn't installed.
- **Framework updates that can't touch your memory.** `sync-upstream` pulls updates through an explicit allowlist; `memory-bank/`, `.rules`, and your ADRs are structurally outside it — and a test enforces that the allowlist never grows to include them.
- **Tested like software, because it is.** Parity, sync-allowlist, and degit-export smoke tests run in CI. The export test guarantees a fresh install ships clean templates — never someone else's project context.

## The shape

```text
your-project/
├── AGENTS.md               # bootstrap — how to read the bank + make changes
├── CLAUDE.md               # @AGENTS.md import for Claude Code
├── .basecamp.json          # provenance anchor — which upstream version you started from
├── .rules                  # learning journal — patterns & preferences
├── memory-bank/
│   ├── projectbrief.md     # what & why; rarely changes
│   ├── productContext.md   # user problem, UX goals
│   ├── systemPatterns.md   # architecture, design decisions
│   ├── techContext.md      # stack, constraints, dependencies
│   ├── decisionLog.md      # durable decisions and ADR index
│   ├── activeContext.md    # current focus — changes most often
│   └── progress.md         # what works, what's left
├── .agents/
│   └── skills/             # Codex-native workflow skills
│       ├── start/
│       ├── discover/
│       ├── from-prd/
│       ├── init-memory/
│       ├── breakdown/
│       ├── review/
│       ├── update-memory/
│       ├── risk-review/
│       ├── decision-log/
│       ├── handoff/
│       ├── ship/
│       ├── ask-claude/
│       ├── sync-upstream/
│       ├── retro/
│       ├── weekly-update/
│       ├── runbook/
│       └── security-check/
├── .claude/
│   └── commands/
│       ├── start.md          # session opener
│       ├── discover.md       # define a project from a rough idea (no code yet)
│       ├── from-prd.md       # seed memory bank from a PRD or brief
│       ├── init-memory.md    # analyze codebase, propose memory bank contents
│       ├── breakdown.md      # break down before executing
│       ├── review.md         # code review the current branch
│       ├── update-memory.md  # refresh the bank
│       ├── weekly-update.md  # stakeholder-ready weekly update
│       ├── retro.md          # sprint or weekly retrospective
│       ├── risk-review.md    # surface undocumented risks
│       ├── decision-log.md   # record an architectural decision (ADR)
│       ├── handoff.md        # generate a handoff doc for the next person
│       ├── ask-codex.md      # ask Codex CLI for a second opinion
│       ├── ship.md           # pre-merge checklist
│       ├── sync-upstream.md  # pull framework updates from upstream
│       ├── runbook.md        # generate/update an operational runbook
│       └── security-check.md # OWASP + STRIDE pass
├── hooks/                    # optional auto-fire (off by default)
│   ├── session-start.sh      # auto-load memory bank at session start
│   ├── pre-compact.sh        # remind agent to update bank before context loss
│   ├── enable-hooks.sh       # register Claude Code hooks
│   └── enable-codex-hooks.sh # register Codex hooks
└── docs/
    ├── workflow-contract.md  # how workflows should be shaped
    └── cross-agent-review.md # second-opinion loop policy
```

That's the framework — markdown files in folders, and the agent does the work. (A `degit` copy also brings Serel Memory's own project metadata — `CONTRIBUTING.md`, `SECURITY.md`, `.github/`, `tests/`, and so on — which isn't part of the framework; delete it after install. See [Install](#install).)

## When *not* to use Serel Memory

Serel Memory is overhead you won't recoup on:

- **Throwaway scripts and one-session tasks** — if you'll never come back to it, there's no memory to preserve.
- **Quick exploratory hacking** where you don't want the agent pausing to read or update a bank.
- **Projects already standardized on another context system** you're happy with (Cursor rules, a bespoke `AGENTS.md`, etc.) — Serel Memory can complement these, but don't adopt it just to have two.

It pays off when you return to a project across many sessions and want continuity that doesn't depend on your memory.

## Install

### On a new project

```bash
npx degit madeordinary/serel-memory#v0.1.0 my-new-project
cd my-new-project
git init
printf '{ "upstream": "madeordinary/serel-memory", "ref": "v0.1.0", "linked": false }\n' > .basecamp.json
```

Then open the project in Claude Code or Codex. There are three paths from here depending on how formed your idea is:

- **If you have a clear idea already** (a paragraph or short brief): paste it into `memory-bank/projectbrief.md`, then run `/start` in Claude Code or invoke `$start` in Codex. The agent reads the bank and asks where to pick up.
- **If you already have a PRD or brief**: put it in the repo, usually under `docs/`, then run `/from-prd docs/prd.md` in Claude Code or invoke `$from-prd docs/prd.md` in Codex. The agent reads the document, asks only for important gaps, then proposes memory bank contents.
- **If your idea is still rough** ("I want to build something that does X..."): run `/discover` in Claude Code or invoke `$discover` in Codex. The agent walks you through targeted questions about the user, problem, scope, and constraints, then proposes memory bank contents based on the dialogue. Good for projects you haven't fully articulated yet.

Codex also discovers the checked-in skills from `.agents/skills/`; use `/skills` or type `$...` to invoke one explicitly.

If Codex shows "Select settings to import" and offers to migrate `.claude/commands` into `.agents/skills`, choose **Not now**. Serel Memory already includes native Codex skills, so importing the Claude commands is unnecessary and may create duplicate workflows.

### On a new project with an existing PRD

If all you have is a PRD, make Serel Memory the starting repo and bring the PRD into it:

```bash
npx degit madeordinary/serel-memory#v0.1.0 my-new-project
cd my-new-project
mkdir -p docs
cp /path/to/prd.md docs/prd.md
git init
printf '{ "upstream": "madeordinary/serel-memory", "ref": "v0.1.0", "linked": false }\n' > .basecamp.json
```

Then run:

```text
# Claude Code
/from-prd docs/prd.md

# Codex
$from-prd docs/prd.md
```

`degit madeordinary/serel-memory#v0.1.0` uses GitHub shorthand for `https://github.com/madeordinary/serel-memory` pinned to the `v0.1.0` tag, and downloads that release's contents without the `.git` history. It is a starter-copy step, not a future `git pull` relationship — which is why the install writes `.basecamp.json`: it records which upstream version you started from, so `sync-upstream` can later show you precisely what changed upstream since, instead of guessing. Pin to the latest tag on the [releases page](https://github.com/madeordinary/serel-memory/releases) and put that same tag in the `ref` field. (Unpinned `npx degit madeordinary/serel-memory` works too, but then the anchor's `ref` is your best guess — if you skip the anchor entirely, `sync-upstream` will offer to reconstruct one marked `"linked": true`, meaning "exact starting version unknown".)

A `degit` copy also brings along Serel Memory's own project metadata — `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `.github/`, and `tests/`. These describe *Serel Memory the project*, not your project, and they aren't part of the framework. Delete them whenever you like; `sync-upstream` never touches them.

### On an existing project

If the project already has code or important files, drop Serel Memory's files in without clobbering anything that's already there:

```bash
cd ~/path/to/your-existing-project

git clone --depth 1 --branch v0.1.0 https://github.com/madeordinary/serel-memory.git /tmp/serel-memory
rsync -av --ignore-existing --exclude 'settings.local.json' /tmp/serel-memory/memory-bank /tmp/serel-memory/.agents /tmp/serel-memory/.claude /tmp/serel-memory/.rules /tmp/serel-memory/AGENTS.md /tmp/serel-memory/CLAUDE.md /tmp/serel-memory/hooks /tmp/serel-memory/docs .
rm -rf /tmp/serel-memory
[ -e .basecamp.json ] || printf '{ "upstream": "madeordinary/serel-memory", "ref": "v0.1.0", "linked": false }\n' > .basecamp.json
```

The `rsync` command is intentionally one line so shell line-continuation mistakes cannot drop the source/destination arguments. Existing files and folders, including something like `docs/prd.md`, are preserved because `--ignore-existing` skips paths that are already present.

Do not run `degit` directly into an existing git repo with files unless you have already reviewed what it will overwrite. The `rsync --ignore-existing` path above is safer because it skips files that already exist. That also means existing `AGENTS.md`, `.rules`, `.claude/`, or `.agents/` files may need a manual merge to pick up Serel Memory's instructions and workflows.

Then — and this is the part most people miss — *don't fill the memory bank by hand.* Open Claude Code and run `/init-memory`, or open Codex and invoke `$init-memory`. The agent reads your codebase, your README, and your dependencies, then proposes contents for each memory bank file. Review the drafts, edit anything that's off, approve, and the agent writes them. This is faster than filling templates from blank and catches things you'd forget to write down.

After that, run `/start` or invoke `$start` to verify the bootstrap works.

## A 5-minute tour

**At session start:** the agent reads every file in `memory-bank/` in order, then `.rules`, then the recent git log. By default (`/start` or `$start`), it tells you in five lines what the project is, what you were last doing, and asks where to pick up. Use `/start full` or `$start full` for a rich onboarding dashboard with recent progress, current state analysis, prioritized next steps, and direction options — useful when you're returning after a break or onboarding a collaborator.

**While working:** the agent keeps `activeContext.md` honest as the focus shifts. When it discovers a non-obvious pattern or preference, it appends to `.rules`.

**When decisions matter:** run `/decision-log` or invoke `$decision-log`. The agent drafts an ADR in `docs/decisions/` and adds a short entry to `memory-bank/decisionLog.md`, so future sessions can see both the decision and the rationale.

**Before merging:** run `/ship`. It walks a checklist — tests pass, docs updated, env vars documented, `progress.md` reflects the change — and tells you ship or don't ship.

**At session end:** run `/update-memory`. The agent refreshes `activeContext.md`, `progress.md`, and `decisionLog.md` when decisions changed, shows you the diffs, and asks before writing.

Claude slash commands and Codex skills are just markdown files. Read them. Change them. They're your workflows, not anyone else's.

## When context gets full

When a chat is getting long or the agent is losing the thread:

1. Run `/update-memory` in Claude Code or invoke `$update-memory` in Codex.
2. Start a fresh conversation or session.
3. Run `/start` or invoke `$start`.

Plain English works too: say "update memory bank", then "start from the memory bank."

## Hooks (optional)

Manual workflows depend on you remembering to run them. Hooks make session-start memory loading happen automatically, and Claude Code hooks also remind you to update memory before compaction. They're **off by default** — opt in per project.

> Prerequisites: the enable scripts are `bash` and use `jq` to edit the JSON settings (if `jq` is missing they print the block for you to paste). On Windows, run them under WSL or Git Bash. The memory bank itself needs none of this — it's just markdown.

To enable Claude Code hooks on a project:

```bash
bash hooks/enable-hooks.sh
```

That adds entries to `.claude/settings.json` registering two hooks:

- **SessionStart** runs `hooks/session-start.sh`, which reads the memory bank + `.rules` + recent git activity and injects it as session context. No more remembering `/start`.
- **PreCompact** runs `hooks/pre-compact.sh`, which reminds the agent to update `activeContext.md`, `progress.md`, and `decisionLog.md` before Claude Code compacts context and erases history. No more stale bank.

To disable temporarily for a session:

```bash
export SEREL_MEMORY_HOOKS=off
```

The Basecamp-era spelling remains supported throughout v0.x:

```bash
export BASECAMP_HOOKS=off
```

To disable permanently, remove the entries from `.claude/settings.json`.

To enable Codex hooks on a project:

```bash
bash hooks/enable-codex-hooks.sh
```

That adds a repo-local `.codex/hooks.json` with a `SessionStart` hook. Codex will ask you to review/trust the hook before running it.

Enable hooks on projects where memory continuity matters and you'd rather not type the commands. Keep them off for exploratory hacking where the bank is overhead. See `hooks/README.md` for the full details.

## Works with both Claude and Codex

The trick is that `AGENTS.md` is the canonical bootstrap and `CLAUDE.md` is a one-line file that imports it. Codex CLI auto-reads `AGENTS.md`. Claude Code auto-reads `CLAUDE.md` and follows the `@AGENTS.md` import. Same source of truth, both tools.

The adapters are native to each tool:

- Claude Code uses `.claude/commands/<name>.md` slash commands.
- Codex uses `.agents/skills/*/SKILL.md` skills.
- Optional hooks can auto-load context for either tool, but the memory bank still works without hooks.

Every workflow has native adapters on both sides:

| Workflow | Claude Code | Codex |
|----------|-------------|-------|
| Start/resume (compact) | `/start` | `$start` |
| Start/resume (full dashboard) | `/start full` | `$start full` |
| Discover from rough idea | `/discover` | `$discover` |
| Seed from PRD | `/from-prd` | `$from-prd` |
| Initialize from code | `/init-memory` | `$init-memory` |
| Breakdown | `/breakdown` | `$breakdown` |
| Review | `/review` | `$review` |
| Update memory | `/update-memory` | `$update-memory` |
| Weekly update | `/weekly-update` | `$weekly-update` |
| Retro | `/retro` | `$retro` |
| Risk review | `/risk-review` | `$risk-review` |
| Decision log | `/decision-log` | `$decision-log` |
| Handoff | `/handoff` | `$handoff` |
| Ship check | `/ship` | `$ship` |
| Ask other agent | `/ask-codex` | `$ask-claude` |
| Sync upstream | `/sync-upstream` | `$sync-upstream` |
| Runbook | `/runbook` | `$runbook` |
| Security check | `/security-check` | `$security-check` |

You can also use plain English when that is more natural:

| What you want | Plain English |
|---------------|---------------|
| Start (compact) | "start from the memory bank" |
| Start (full dashboard) | "start full" or "give me the full onboarding" |
| Initialize from code | "initialize memory from this repo" |
| Seed from PRD | "seed memory from this PRD" |
| Update memory | "update memory bank" |
| Record decision | "record this decision" |
| Review plan with another agent | "ask Claude/Codex for a second opinion" |

## Workflow design

Serel Memory workflows follow a small contract: define the trigger, required reads, allowed writes, output shape, and stop conditions. See `docs/workflow-contract.md`.

The core memory bank has a hierarchy:

- `projectbrief.md` is the foundation: what and why.
- `productContext.md` explains the user and job.
- `systemPatterns.md`, `techContext.md`, and `decisionLog.md` capture durable implementation context.
- `activeContext.md` is the current working state.
- `progress.md` is the honest status snapshot.
- `.rules` is the learning journal for reusable preferences and gotchas.

The memory bank uses a promotion path:

- Current session state belongs in `activeContext.md`.
- Completed status belongs in `progress.md`.
- Durable decisions belong in `decisionLog.md` and, when useful, `docs/decisions/`.
- Reusable preferences, gotchas, and rejected approaches belong in `.rules`.

This keeps the bank useful instead of turning it into a chat transcript.

## Extending the memory bank

Keep the core bank small. If a topic is too large for the core files, add focused optional docs under `memory-bank/`, for example:

- `memory-bank/features/<feature>.md`
- `memory-bank/integrations/<service>.md`
- `memory-bank/ops/<runbook-context>.md`
- `memory-bank/testing.md`

These are optional. Agents should read them only when the current task touches that topic.

## Optional Second Opinions

If you use both Claude Code and Codex, Serel Memory includes an advanced second-opinion workflow:

- In Claude Code, run `/ask-codex` to ask Codex CLI to review a plan, architecture decision, PRD interpretation, or risk assessment.
- In Codex, invoke `$ask-claude` to ask Claude Code CLI for the same kind of review.

These workflows shell out to the other CLI; they do not require MCP. They use the other CLI when it's installed and authenticated, and fall back to a clearly labeled self-critique when it isn't. The default mode is a single read-only review. A bounded loop is available only when you explicitly ask for it, capped at 2 rounds by default, and should end with a synthesis rather than autonomous edits.

If a local Claude invocation is unavailable but Claude Code Web is authorized,
the same review can run from a fresh web session against an exact pushed branch
SHA. The cross-agent guide documents that remote-branch flow and its gate
boundaries.

See `docs/cross-agent-review.md` for the CLI preflight, loop policy, and output contract.

## Why this exists

The memory bank pattern is borrowed from [cline's memory bank](https://github.com/nickbaumann98/cline_docs), which is excellent but Cline-specific. The workflow-command shape is borrowed in spirit from [gstack](https://github.com/garrytan/gstack), which is excellent but broader than most projects need on day one.

Serel Memory is the smallest thing that delivers both — a tool-agnostic memory bank that works with Claude and Codex, plus a curated set of workflows you'll actually run.

If you fork it, change everything. The workflows especially. The whole point is that the prompts encode *your* opinions, not anyone else's.

## License

MIT.
