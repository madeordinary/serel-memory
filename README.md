# basecamp

A portable memory bank and workflow kit for AI coding agents. Works with Claude Code and Codex out of the box.

## The problem

AI coding agents lose their memory between sessions. Every new conversation starts from zero. The agent doesn't remember what you're building, what you decided last week, which patterns you've already rejected, or what's currently broken.

The usual fix is to dump a paragraph of context into every prompt. That works until you forget something, or the context grows beyond what fits, or you switch tools and have to do it all again.

basecamp is the other fix: a small, opinionated directory of markdown files the agent reads at the start of every session, so context doesn't depend on your memory.

## The shape

```
your-project/
├── AGENTS.md               # bootstrap — tells the agent how to read the bank
├── CLAUDE.md               # @AGENTS.md import for Claude Code
├── .rules                  # learning journal — patterns & preferences
├── memory-bank/
│   ├── projectbrief.md     # what & why; rarely changes
│   ├── productContext.md   # user problem, UX goals
│   ├── systemPatterns.md   # architecture, design decisions
│   ├── techContext.md      # stack, constraints, dependencies
│   ├── activeContext.md    # current focus — changes most often
│   └── progress.md         # what works, what's left
├── .agents/
│   └── skills/             # Codex-native workflow skills
│       ├── basecamp-start/
│       ├── basecamp-discover/
│       ├── basecamp-from-prd/
│       ├── basecamp-init-memory/
│       ├── basecamp-update-memory/
│       └── basecamp-ship/
├── .claude/
│   └── commands/
│       ├── start.md          # session opener
│       ├── discover.md       # define a project from a rough idea (no code yet)
│       ├── from-prd.md       # seed memory bank from a PRD or brief
│       ├── init-memory.md    # analyze codebase, propose memory bank contents
│       ├── plan.md           # plan before executing
│       ├── review.md         # code review the current branch
│       ├── update-memory.md  # refresh the bank
│       ├── weekly-update.md  # stakeholder-ready weekly update
│       ├── retro.md          # sprint or weekly retrospective
│       ├── risk-review.md    # surface undocumented risks
│       ├── decision-log.md   # record an architectural decision (ADR)
│       ├── handoff.md        # generate a handoff doc for the next person
│       ├── ship.md           # pre-merge checklist
│       ├── runbook.md        # generate/update an operational runbook
│       └── security-check.md # OWASP + STRIDE pass
└── hooks/                    # optional auto-fire (off by default)
    ├── session-start.sh      # auto-load memory bank at session start
    ├── pre-compact.sh        # auto-update memory bank before context loss
    ├── enable-hooks.sh       # register Claude Code hooks
    └── enable-codex-hooks.sh # register Codex hooks
```

That's all of it. Markdown files in folders. The agent does the work.

## Install

### On a new project

```bash
npx degit gusfeliciano/basecamp my-new-project
cd my-new-project
git init
```

Then open the project in Claude Code or Codex. There are three paths from here depending on how formed your idea is:

- **If you have a clear idea already** (a paragraph or short brief): paste it into `memory-bank/projectbrief.md`, then run `/start` in Claude Code or invoke `$basecamp-start` in Codex. The agent reads the bank and asks where to pick up.
- **If you already have a PRD or brief**: put it in the repo, usually under `docs/`, then run `/from-prd docs/prd.md` in Claude Code or invoke `$basecamp-from-prd docs/prd.md` in Codex. The agent reads the document, asks only for important gaps, then proposes memory bank contents.
- **If your idea is still rough** ("I want to build something that does X..."): run `/discover` in Claude Code or invoke `$basecamp-discover` in Codex. The agent walks you through targeted questions about the user, problem, scope, and constraints, then proposes memory bank contents based on the dialogue. Good for projects you haven't fully articulated yet.

Codex also discovers the checked-in skills from `.agents/skills/`; use `/skills` or type `$basecamp-...` to invoke one explicitly.

### On a new project with an existing PRD

If all you have is a PRD, make basecamp the starting repo and bring the PRD into it:

```bash
npx degit gusfeliciano/basecamp my-new-project
cd my-new-project
mkdir -p docs
cp /path/to/prd.md docs/prd.md
git init
```

Then run:

```text
# Claude Code
/from-prd docs/prd.md

# Codex
$basecamp-from-prd docs/prd.md
```

`degit gusfeliciano/basecamp` uses GitHub shorthand for `https://github.com/gusfeliciano/basecamp` and downloads the current repo contents without the `.git` history. It is a starter-copy step, not a future `git pull` relationship.

### On an existing project

If the project already has code or important files, drop basecamp's files in without clobbering anything that's already there:

```bash
cd ~/path/to/your-existing-project

git clone --depth 1 https://github.com/gusfeliciano/basecamp.git /tmp/basecamp
rsync -av --ignore-existing \
  /tmp/basecamp/{memory-bank,.agents,.claude,.rules,AGENTS.md,CLAUDE.md,hooks} .
rm -rf /tmp/basecamp
```

Then — and this is the part most people miss — *don't fill the memory bank by hand.* Open Claude Code and run `/init-memory`, or open Codex and invoke `$basecamp-init-memory`. The agent reads your codebase, your README, and your dependencies, then proposes contents for each memory bank file. Review the drafts, edit anything that's off, approve, and the agent writes them. This is faster than filling templates from blank and catches things you'd forget to write down.

After that, run `/start` or invoke `$basecamp-start` to verify the bootstrap works.

## A 5-minute tour

**At session start:** the agent reads every file in `memory-bank/` in order, then `.rules`, then the recent git log. It tells you in five lines what the project is, what you were last doing, and asks where to pick up.

**While working:** the agent keeps `activeContext.md` honest as the focus shifts. When it discovers a non-obvious pattern or preference, it appends to `.rules`.

**Before merging:** run `/ship`. It walks a checklist — tests pass, docs updated, env vars documented, `progress.md` reflects the change — and tells you ship or don't ship.

**At session end:** run `/update-memory`. The agent refreshes `activeContext.md` and `progress.md`, shows you the diffs, and asks before writing.

Claude slash commands and Codex skills are just markdown files. Read them. Change them. They're your workflows, not anyone else's.

## Hooks (optional)

Manual workflows depend on you remembering to run them. Hooks make session-start memory loading happen automatically, and Claude Code hooks also remind you to update memory before compaction. They're **off by default** — opt in per project.

To enable Claude Code hooks on a project:

```bash
bash hooks/enable-hooks.sh
```

That adds entries to `.claude/settings.json` registering two hooks:

- **SessionStart** runs `hooks/session-start.sh`, which reads the memory bank + `.rules` + recent git activity and injects it as session context. No more remembering `/start`.
- **PreCompact** runs `hooks/pre-compact.sh`, which reminds the agent to update `activeContext.md` and `progress.md` before Claude Code compacts context and erases history. No more stale bank.

To disable temporarily for a session:

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
- Codex uses `.agents/skills/basecamp-*/SKILL.md` skills.
- Optional hooks can auto-load context for either tool, but the memory bank still works without hooks.

## Why this exists

The memory bank pattern is borrowed from [cline's memory bank](https://github.com/nickbaumann98/cline_docs), which is excellent but Cline-specific. The workflow-command shape is borrowed in spirit from [gstack](https://github.com/garrytan/gstack), which is excellent but ships 23 commands when most projects need seven.

basecamp is the smallest thing that delivers both — a tool-agnostic memory bank that works with Claude and Codex, plus a curated set of workflows you'll actually run.

If you fork it, change everything. The workflows especially. The whole point is that the prompts encode *your* opinions, not anyone else's.

## License

MIT.
