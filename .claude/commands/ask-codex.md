---
description: "Ask Codex CLI for an independent second opinion while working in Claude Code. Use when the user wants Codex to review a plan, architecture decision, PRD interpretation, implementation approach, or risk assessment. Supports optional bounded loop mode when explicitly requested."
---

# /ask-codex

Use this when the user wants an independent Codex review of a plan, architecture decision, implementation approach, PRD interpretation, or risk assessment while working in Claude Code.

This workflow shells out to the Codex CLI. It does not require MCP.

## Preconditions

- `codex` should be installed and authenticated. If it isn't, don't block — use the Fallback at the end.
- The user must approve any shell execution required by their environment.
- Do not pass secrets, credentials, private production data, or sensitive customer data into the prompt.
- Follow `docs/cross-agent-review.md` when present.

## Default: Single-Pass Review

1. Identify the artifact to review:
   - A plan from the current conversation
   - A file path
   - A diff
   - A proposed architecture or decision
2. Build a concise prompt for Codex:

   ```text
   You are an independent engineering reviewer.
   Do not edit files.
   Do not run write operations.
   Review the plan/artifact below for:
   - incorrect assumptions
   - missing risks
   - simpler alternatives
   - validation gaps
   - questions the primary agent should ask the user

   Return:
   AGREEMENTS:
   DISAGREEMENTS:
   RISKS:
   SUGGESTED CHANGES:
   QUESTIONS:
   VERDICT: APPROVE | REVISE | RETHINK

   <plan/artifact/context>
   ```

3. Verify Codex CLI is available when practical:

   ```bash
   codex --version
   ```

4. Run Codex in read-only mode. Long prompts passed inline as an argument can
   hang `codex exec` — always write the prompt to a temp file and pipe it, in
   a single shell invocation (shell state doesn't survive across tool calls):

   ```bash
   PROMPT_FILE="$(mktemp)"
   cat > "$PROMPT_FILE" <<'EOF'
   ...the full prompt...
   EOF
   codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
   rm -f "$PROMPT_FILE"
   ```

5. Summarize Codex's response for the user:
   - Verdict (APPROVE / REVISE / RETHINK)
   - Agreements
   - Gaps or disagreements
   - Plan changes worth adopting
   - Questions to ask before proceeding
6. Stop and wait for the user.

## Advanced: Bounded Loop

Use loop mode only when the user explicitly asks for a loop, debate, back-and-forth, or "have Claude and Codex work it out."

Rules:

- Maximum 2 rounds by default.
- Maximum 3 rounds if the user explicitly asks, or without asking when a HIGH security, auth, data-loss or concurrency finding is still open with evidence after round 2; say so in the synthesis. Never more than 3.
- A timeout, an error, or no reply from Codex is not approval, and neither is reaching the cap.
- No file edits during the loop.
- Each round must get shorter and more specific.
- Stop early when the remaining disagreement is a product judgment, user preference, or low-impact implementation detail.
- Never ask Codex to call Claude back. The current Claude session owns the loop.

Loop structure:

1. Round 1: Ask Codex for broad critique.
2. Claude summarizes what it accepts, rejects, and wants challenged, as a findings ledger: a stable id per finding (F1, F2, …) with its outcome — fixed, disputed with evidence, or declined as a follow-up ("Findings ledger" in `docs/cross-agent-review.md`).
3. Round 2: Ask Codex only about unresolved disagreements or high-risk gaps. Send the ledger plus only the changed parts, and ask Codex to mark each id resolved or still open.
4. Produce final synthesis:

   ```text
   FINAL SYNTHESIS:
   - What both agents agree on
   - What changed in the plan
   - Remaining disagreements
   - User decisions needed
   - Recommended next step
   ```

Then stop and wait.

## Fallback

If `codex` is missing, not authenticated, or blocked, say so and perform a local critique instead. Do not pretend Codex reviewed it.
