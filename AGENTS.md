# Project Agent Instructions

You are working on a project that uses the basecamp memory bank pattern. Your memory resets between sessions — the memory bank is your only continuity. Treat it as the source of truth for project intent.

## At the start of every session

Read these files, in this order, before doing anything else:

1. `memory-bank/projectbrief.md` — what we're building and why
2. `memory-bank/productContext.md` — the user problem and UX goals
3. `memory-bank/systemPatterns.md` — architecture and design decisions
4. `memory-bank/techContext.md` — stack, constraints, dependencies
5. `memory-bank/activeContext.md` — current focus (most important)
6. `memory-bank/progress.md` — what works, what's broken
7. `.rules` — project-specific patterns and preferences

Then read the last 5–10 git commits for recent context.

If any memory bank file is missing or empty, note it and ask the user before proceeding.

## While working

- Keep `activeContext.md` honest as the focus shifts during the session.
- When you discover a non-obvious pattern or user preference, append it to `.rules`.
- Before significant work, propose a plan and wait for confirmation.
- The memory bank is the source of truth for intent. If it conflicts with the actual code, the code is correct and the bank needs updating — flag this so the user can decide.

## When the user says "update memory bank"

Refresh every file in `memory-bank/`. Focus especially on `activeContext.md` and `progress.md`. Show diffs before writing.

## Available slash commands

The `.claude/commands/` directory contains opinionated prompts for specific workflows:

- `/start` — read the bank, summarize state, ask where to pick up
- `/init-memory` — analyze the codebase and propose initial memory bank contents (use when bank is empty)
- `/plan` — break a task into steps before executing
- `/review` — code review the current branch or diff
- `/update-memory` — refresh the memory bank from this session's work
- `/weekly-update` — draft a stakeholder-ready weekly update from the bank and recent activity
- `/ship` — pre-merge checklist
- `/runbook` — generate or update an operational runbook
- `/security-check` — OWASP + STRIDE pass on the current change

If you're not running in Claude Code (which natively loads slash commands), the prompts in those files are still useful — read them as guidance for the corresponding action.

## Ground rules

- Don't assume project context that isn't supported by the memory bank. Ask.
- Don't overwrite memory bank files silently. Show diffs first.
- Don't bloat the bank — it's signal, not journal. One-offs don't belong.
- Code is the source of truth for what currently works. The bank is the source of truth for what we *meant* to build.
