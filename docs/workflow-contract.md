# Workflow Contract

Basecamp workflows should be small, explicit, and portable across agents. Use this
contract when adding or revising a Claude command, Codex skill, or future adapter.

## Required sections

Every workflow should make these things clear:

- **Trigger**: when to use it and when not to use it.
- **Required reads**: files, diffs, logs, or docs the agent must inspect first.
- **Allowed writes**: files the workflow may edit, and whether confirmation is required.
- **Output contract**: the exact shape users should expect back.
- **Stop conditions**: when the agent must pause for user input instead of guessing.

## Resolving the effective bank

Every reference to "the memory bank" or `.rules` in a workflow means the
**effective bank**:

- If `memory-bank.local/` exists (upstream basecamp development only — it is
  gitignored and never ships), it is the effective bank: read and write its
  files instead of the tracked `memory-bank/`, and `memory-bank.local/.rules`
  instead of root `.rules`. It is partial by design; for core files it lacks,
  `README.md` and `docs/` carry intent — don't flag the blank tracked
  templates as uninitialized, and never write maintainer state to them.
- Otherwise (every downstream project), the effective bank is `memory-bank/`
  and root `.rules`.

## Defaults

- Read `AGENTS.md`, the relevant memory-bank files, `.rules`, and recent git history when project intent matters.
- Treat code as source of truth for current behavior.
- Treat the memory bank as source of truth for intended behavior once initialized.
- Show diffs before writing memory-bank files.
- Ask before changing product scope, architecture, dependencies, security posture, or public behavior.
- Prefer one focused workflow over a broad persona.
- Read optional `memory-bank/` docs only when the current task clearly touches that topic.

## Optional memory docs

Keep the core memory bank small. When a topic outgrows the core files, add focused
optional docs under `memory-bank/`, for example:

- `memory-bank/features/<feature>.md`
- `memory-bank/integrations/<service>.md`
- `memory-bank/ops/<runbook-context>.md`
- `memory-bank/testing.md`

Optional docs are not part of the required startup read. Agents should find and
read them only when relevant to the task.

## Memory writes

Use this promotion path:

1. Current task details go in the conversation or temporary plan.
2. Current session state goes in `memory-bank/activeContext.md`.
3. Completed status goes in `memory-bank/progress.md`.
4. Durable decisions go in `memory-bank/decisionLog.md` and, when useful, `docs/decisions/`.
5. Reusable patterns and gotchas go in `.rules`.
6. Stable architecture goes in `memory-bank/systemPatterns.md`.

Do not turn the memory bank into a journal. A line should survive because it helps
the next session make a better decision.
