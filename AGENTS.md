# Project Agent Instructions

You are working on a project that uses the basecamp memory bank pattern. Your memory resets between sessions — the memory bank is your only continuity. Treat it as the source of truth for project intent.

## At the start of every session

Read these files, in this order, before doing anything else:

1. `memory-bank/projectbrief.md` — what we're building and why
2. `memory-bank/productContext.md` — the user problem and UX goals
3. `memory-bank/systemPatterns.md` — architecture and design decisions
4. `memory-bank/techContext.md` — stack, constraints, dependencies
5. `memory-bank/decisionLog.md` — durable decisions and ADR index
6. `memory-bank/activeContext.md` — current focus (most important)
7. `memory-bank/progress.md` — what works, what's broken
8. `.rules` — project-specific patterns and preferences

Then read the last 5–10 git commits for recent context.

If the task clearly touches a specific feature, integration, deployment path, testing strategy, or API, look for relevant optional docs under `memory-bank/` and read only the ones that apply.

If any memory bank file is missing, empty, or still only template placeholders, note it and ask the user before proceeding.

## While working

- Keep `activeContext.md` honest as the focus shifts during the session.
- When you discover a non-obvious pattern or user preference, append it to `.rules`.
- Before significant work, propose a plan and wait for confirmation.
- The memory bank is the source of truth for intent. If it conflicts with the actual code, the code is correct and the bank needs updating — flag this so the user can decide.

## When the user says "update memory bank"

Refresh every file in `memory-bank/`. Focus especially on `activeContext.md`, `progress.md`, and `decisionLog.md` when decisions changed. Show diffs before writing.

## Available workflows

The `.claude/commands/` directory contains Claude Code slash commands, and `.agents/skills/` contains Codex-native skills for core basecamp workflows:

- `/start` / `$start` — read the bank, summarize state, ask where to pick up (compact; use `/start full` for rich onboarding dashboard)
- `/discover` / `$discover` — help the user define a project from a rough idea; produces initial memory bank (use when starting fresh with no code yet)
- `/from-prd` / `$from-prd` — seed the memory bank from an existing PRD, product brief, spec, or requirements doc
- `/init-memory` / `$init-memory` — analyze the codebase and propose initial memory bank contents (use when bank is empty but code already exists)
- `/breakdown` / `$breakdown` — break a task into steps before executing
- `/review` / `$review` — code review the current branch or diff
- `/update-memory` / `$update-memory` — refresh the memory bank from this session's work
- `/weekly-update` / `$weekly-update` — stakeholder-ready weekly update from the bank and recent activity
- `/retro` / `$retro` — sprint or weekly retrospective drawing from progress and git log
- `/risk-review` / `$risk-review` — surface risks not yet documented in the bank
- `/decision-log` / `$decision-log` — record an architectural decision in ADR format
- `/handoff` / `$handoff` — generate a handoff doc for someone picking up the project cold
- `/ask-codex` / `$ask-claude` — ask the other CLI for an optional second opinion on plans, risks, and decisions
- `/ship` / `$ship` — pre-merge checklist
- `/sync-upstream` / `$sync-upstream` — check the upstream basecamp repo for framework updates and selectively pull changes
- `/runbook` / `$runbook` — generate or update an operational runbook
- `/security-check` / `$security-check` — OWASP + STRIDE pass on the current change

If a workflow does not yet have a Codex skill, read the corresponding `.claude/commands/<name>.md` file as guidance for the action.

## Cross-agent planning

Before implementing any non-trivial plan (3+ steps or touching multiple files), get a second opinion from the other agent CLI:

- **In Claude Code**: shell out to `codex exec --cd "$PWD" --sandbox read-only "<prompt>"` for a read-only Codex review.
- **In Codex**: shell out to `claude -p --permission-mode plan "<prompt>"` for a read-only Claude review.

The `/breakdown` and `$breakdown` workflows do this automatically. For ad-hoc plans outside of breakdown, follow the same pattern: build the plan, get the second opinion, present both to the user.

If the other CLI is unavailable, perform a local self-critique instead — but say so. Never skip the review and never pretend the other agent reviewed it.

See `docs/cross-agent-review.md` for the output contract, loop policy, and CLI preflight.

## Ground rules

- Don't assume project context that isn't supported by the memory bank. Ask.
- Don't overwrite memory bank files silently. Show diffs first.
- Don't bloat the bank — it's signal, not journal. One-offs don't belong.
- Code is the source of truth for what currently works. The bank is the source of truth for what we *meant* to build.
- Before implementing significant work, get a cross-agent second opinion on the plan (see above).
