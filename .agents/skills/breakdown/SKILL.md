---
name: breakdown
description: "Break down a task before implementation. Use when the user asks to plan, break down work, assess scope, or decide how to proceed before editing."
---

# Breakdown

For the task the user just described, do NOT take any action yet: produce a plan first. Do not edit files while planning.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

## Workflow

1. Read the relevant memory-bank files for project intent, so the plan is grounded, not guessed:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Inspect only the source files you need to make the plan concrete.
4. Produce the plan in this order:

```text
GOAL:
[one sentence — what success looks like]

SCOPE:
[the specific files, components, or areas you'll touch — paths, function names]

STEPS:
1. [verb + concrete action] → verify: [how you'll know it worked]
2. [verb + concrete action] → verify: [how you'll know it worked]
3. [verb + concrete action] → verify: [how you'll know it worked]

RISKS & UNKNOWNS:
- [what could go wrong, what you'd need to verify first, what assumptions you're making]

OUT OF SCOPE:
- [what this plan will deliberately not do, in case the user wants it too]

MEMORY USED:
- [bank path § section] → [the step, constraint, or verify check it changed] (or: none)

MEMORY CONFLICTS:
- [bank path § section] [current fact | durable decision | intended future | open question]: [conflict] → [what the plan does about it] (or: none)
```

## Cross-agent review (recommended for high-impact plans)

For high-impact or hard-to-reverse plans (architecture, security/auth, data migrations, public API or schema, dependency choices), get a second opinion from the other model before presenting to the user. For routine changes it's optional — use judgment.

Which CLI am I running in? Use only the matching branch below; never call your own CLI.

- **In Claude Code:** your model is Claude and the other model is Codex. It is available if `codex --version` succeeds. Run Codex in read-only mode. Write the prompt to a temp file and pipe it — long inline prompts can hang `codex exec`:

  ```bash
  PROMPT_FILE="$(mktemp)"
  cat > "$PROMPT_FILE" <<'EOF'
  ...the full prompt...
  EOF
  codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
  rm -f "$PROMPT_FILE"
  ```

- **In Codex:** your model is Codex and the other model is Claude. It is available if `claude --version` succeeds. Shell out to Claude in read-only mode. Write the prompt to a temp file and pipe it via stdin — long inline prompts are unreliable as CLI arguments:

  ```bash
  PROMPT_FILE="$(mktemp)"
  cat > "$PROMPT_FILE" <<'EOF'
  ...the full prompt...
  EOF
  claude -p --permission-mode plan < "$PROMPT_FILE"
  rm -f "$PROMPT_FILE"
  ```

Then, in either CLI:

1. Check whether the other model is available, using your branch's check.
2. If it is, build a concise prompt with the plan, the goal, and enough project context for a meaningful review, asking it to end with a one-line verdict (`VERDICT: APPROVE | REVISE | RETHINK`, pick exactly one), then run your branch's block. Write the prompt file and run the other model in a single shell invocation (shell state doesn't survive across tool calls).
3. Append a second-opinion section to the plan output, **Second Opinion (Codex)** in Claude Code or **Second Opinion (Claude)** in Codex:
   - Verdict (APPROVE / REVISE / RETHINK)
   - Agreements
   - Disagreements or gaps
   - Suggested changes worth adopting
   - Questions to resolve before proceeding

If the other model's CLI is not installed or not authenticated, don't block — perform a local self-critique instead and label it **Self-Critique (Codex unavailable)** in Claude Code or **Self-Critique (Claude unavailable)** in Codex, so the user knows no independent review happened. Never pretend the other model reviewed it.

Then end with: **"Want me to proceed, or change something first?"**

Wait. Do not start executing until the user confirms.

## Rules

- Keep plans to 3–7 concrete steps, each starting with a verb (add, refactor, test, document, deploy). If the plan is longer than 7 steps, the task is too big — recommend splitting it.
- Each step ends with `→ verify: [how you'll know it worked]`. Reframe imperative steps as verifiable goals — "add validation" becomes "write tests for invalid inputs, then make them pass".
- If you have to assume something material, say so explicitly. Don't bury assumptions inside step descriptions.
- If the request has more than one reasonable interpretation, lay them out and ask which one — don't silently pick.
- If the memory bank, including `decisionLog.md`, is blank, stale, or contradictory, or doesn't have enough context for the plan, say what's missing and ask before guessing.
- `MEMORY USED` lists each bank entry that changed the plan — its path and section, and the step, constraint, or verify check it changed. List only entries that changed something, not everything you read; write "none" if nothing did. That relevance applies to the whole plan: don't raise risks, questions, or follow-ups from bank entries unrelated to the request, or infer components the task lacks from them — but keep real unknowns and applicable accepted decisions visible.
- `MEMORY CONFLICTS` lists where the bank disagrees with the code, the request, or itself, classified as current fact, durable decision, intended future, or open question (contract "Memory accuracy"), and what the plan does about it: plan a stale current fact against the code and flag it for `update-memory`; take a request or code that breaks an accepted decision to the user; a proposed decision is an open question, not a constraint. Write "none" if there are none.
- Do not start implementation until the user confirms.
