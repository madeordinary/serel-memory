---
description: Refresh the memory bank from this session's work
---

# /update-memory

Update the memory bank to reflect the work done this session. Show diffs before writing anything.

**Effective bank:** if `memory-bank.local/` exists (upstream basecamp development only), all reads and writes below target it and its `.rules` — never the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

Steps:

1. Read every file in `memory-bank/` and `.rules`.
2. Review what changed in this session — what was built, decided, learned, deferred.
3. Propose updates. Focus especially on:
   - **`activeContext.md`** — refresh current focus, recent changes (top of list), next steps, open questions.
   - **`progress.md`** — move items from "in progress" to "what works"; add new known issues; update phase if it changed.
4. Touch other files only if they need it:
   - `systemPatterns.md` — only if a real architectural decision was made
   - `techContext.md` — only if dependencies, env vars, or runtime changed
   - `decisionLog.md` — only if a durable architectural, product, workflow, or operational decision was made. If a past decision changed, **supersede, don't delete**: append "SUPERSEDED by … (date)" and move it to the Superseded section.
   - `productContext.md` / `projectbrief.md` — only if the goal or user model actually shifted
5. Append to `.rules` any non-obvious thing learned this session: a user preference, a gotcha, a rejected approach worth remembering. Then **prune `.rules`**: if it's over ~40 lines or holds stale/obsolete lines, drop what's no longer true and promote stabilized conventions into `systemPatterns.md`. Keep it high-signal, not append-forever.

For each proposed change, show:

```text
FILE: [path]
CHANGE: [add / update / remove]
DIFF:
[show the actual before/after for the affected section]
```

## Bank-vs-reality audit (offered)

The bank update is the agent writing the durable record of its own session —
the purest self-grading moment in the framework. After showing the proposed
diffs and before asking for confirmation, if `codex --version` succeeds and the
session wasn't trivial (docs-only or a tiny diff), offer once:

> Want Codex to verify these updates against the actual repo? (~30–90s, read-only)

If accepted:

1. Write a prompt file containing the proposed diff blocks, a 2–3 line session
   summary, the instructions below, and a read-only instruction (do not edit
   files or run write operations), then run Codex read-only — synchronous
   form, `docs/cross-agent-review.md` has the canonical invocation:

   ```bash
   codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
   ```

2. Ask Codex to classify each claim in the proposed updates as **current
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

If Codex is unavailable or the user declines, continue single-model — the
audit never blocks a bank update.

Wait for confirmation before writing any file. If the user pushes back, revise — don't argue.

Rules:

- Don't bloat. Every line in the bank should still be earning its place.
- Don't journal — this isn't a log. Old `activeContext.md` entries don't need to be preserved.
- If `.rules` already covers a learning, refine the existing entry instead of duplicating.
- Follow `docs/workflow-contract.md` when present: session state goes to `activeContext.md`, completed status to `progress.md`, durable decisions to `decisionLog.md`, reusable gotchas to `.rules`.
