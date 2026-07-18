---
name: update-memory
description: "Refresh memory-bank files after a work session. Use when the user asks to update memory, preserve session context, refresh activeContext/progress, or capture new project learnings."
---

# Update Memory

Use this skill to update the memory bank from the current session. Always show proposed diffs before writing.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), all reads and writes below target it and its `.rules` — never the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

## Workflow

1. Read every file in `memory-bank/` and `.rules`.
2. Review what changed this session: built, decided, learned, deferred, or discovered.
3. Propose updates, focusing on:
   - `memory-bank/activeContext.md` - current focus, recent changes, next steps, open questions
   - `memory-bank/progress.md` - what works, in progress, known issues, phase
4. Touch other files only if needed:
   - `systemPatterns.md` for real architectural decisions
   - `techContext.md` for dependencies, environment variables, runtime, or operational constraints
   - `decisionLog.md` for durable architectural, product, workflow, or operational decisions. If a past decision changed, **supersede, don't delete**: append "SUPERSEDED by … (date)" and move it to the Superseded section.
   - `productContext.md` or `projectbrief.md` only if product intent changed
5. Append to `.rules` only for non-obvious reusable learnings, then **prune** it: if it's over ~40 lines or holds stale lines, drop what's no longer true and promote stabilized conventions into `systemPatterns.md`.

For each proposed change, show:

```text
FILE: [path]
CHANGE: [add / update / remove]
DIFF:
[actual before/after for the affected section]
```

## Bank-vs-reality audit (offered)

The bank update is the agent writing the durable record of its own session —
the purest self-grading moment in the framework. After showing the proposed
diffs and before asking for confirmation, if `claude --version` succeeds and
the session wasn't trivial (docs-only or a tiny diff), offer once:

> Want Claude to verify these updates against the actual repo? (~30–90s, read-only)

If accepted:

1. Write a prompt file containing the proposed diff blocks, a 2–3 line session
   summary, the instructions below, and a read-only instruction (do not edit
   files or run write operations), then run Claude read-only — synchronous
   form, `docs/cross-agent-review.md` has the canonical invocation:

   ```bash
   claude -p --permission-mode plan < "$PROMPT_FILE"
   ```

2. Ask Claude to classify each claim in the proposed updates as **current
   fact**, **durable decision**, **intended future**, or **open question** —
   and to flag only *current-fact* claims the code, tests, or git history
   don't support. Intent is allowed to lead the code; facts are not. When a
   claim is ambiguous between fact and intent (present-tense statements in
   `projectbrief.md`, `productContext.md`, or `systemPatterns.md` often
   describe planned state), classify it as intent unless it asserts
   observable build/test/runtime status.
3. Also ask it to scan the session's diff/log for durable changes the draft
   missed — new dependencies, schema changes, pattern shifts that belong in
   `decisionLog.md` or `techContext.md`.
4. Fold accepted findings into the proposed diffs, mark which lines changed
   because of the audit, and show the revised diffs.

If Claude is unavailable or the user declines, continue single-model — the
audit never blocks a bank update.

Wait for confirmation before writing.

## Rules

- Do not bloat the bank.
- Do not journal one-off events.
- If `.rules` already covers a learning, refine the existing entry instead of duplicating it.
- Keep `activeContext.md` current rather than preserving old session history.
- Promote information according to `docs/workflow-contract.md`: session state to `activeContext.md`, completed status to `progress.md`, durable decisions to `decisionLog.md`, reusable gotchas to `.rules`.
