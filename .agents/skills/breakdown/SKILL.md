---
name: breakdown
description: "Break down a task before implementation in Codex. Use when the user asks to plan, break down work, assess scope, or decide how to proceed before editing."
---

# Breakdown

Use this skill when the user wants a plan before execution. Do not edit files while planning.

## Workflow

1. Read the relevant memory-bank files for project intent:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Inspect only the files needed to make the plan concrete.
4. Produce the plan in this order:

```text
GOAL:
[one sentence - what success looks like]

SCOPE:
[specific files, components, or areas likely to change]

STEPS:
1. [verb + concrete action]
2. [verb + concrete action]
3. [verb + concrete action]

RISKS & UNKNOWNS:
- [risk, assumption, or validation gap]

OUT OF SCOPE:
- [what this plan will deliberately not do]
```

## Cross-agent review (recommended for high-impact plans)

For high-impact or hard-to-reverse plans (architecture, security/auth, data migrations, public API or schema, dependency choices), get a Claude second opinion before presenting to the user. For routine changes it's optional — use judgment.

1. Check whether Claude is available: `claude --version`
2. If it is, build a concise prompt with the plan, the goal, and enough project context for a meaningful review, then shell out to Claude in read-only mode. Write the prompt to a temp file and pipe it via stdin — long inline prompts are unreliable as CLI arguments — in a single shell invocation (shell state doesn't survive across tool calls):

   ```bash
   PROMPT_FILE="$(mktemp)"
   cat > "$PROMPT_FILE" <<'EOF'
   ...the full prompt...
   EOF
   claude -p --permission-mode plan < "$PROMPT_FILE"
   rm -f "$PROMPT_FILE"
   ```

3. Append a **Second Opinion (Claude)** section to the output:
   - Agreements
   - Disagreements or gaps
   - Suggested changes worth adopting
   - Questions to resolve before proceeding

If `claude` is not installed or not authenticated, don't block — perform a local self-critique instead and label it **Self-Critique (Claude unavailable)** so the user knows no independent review happened. Never pretend Claude reviewed it.

Then end with: **"Want me to proceed, or change something first?"** and wait.

## Rules

- Keep plans to 3-7 steps. If the work is larger, recommend splitting it.
- Say material assumptions explicitly.
- If the memory bank is blank, stale, or contradictory, say what is missing before guessing.
- Do not start implementation until the user confirms.
