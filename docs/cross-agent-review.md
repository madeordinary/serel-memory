# Cross-Agent Review

Basecamp supports optional second opinions between Claude Code and Codex through
their CLIs. This is intentionally a thin workflow, not a full orchestrator.

## Policy

- Reach for a review on high-impact or hard-to-reverse plans (architecture, security/auth, data migrations, public API or schema, dependency choices). For routine changes it's optional — it's a tool, not a tax.
- Check the other CLI exists first; if it doesn't, do a labeled local self-critique rather than blocking.
- Default to one read-only review.
- Use a loop only when the user explicitly asks for debate, back-and-forth, or a loop.
- Cap loops at 2 rounds by default.
- Cap at 3 rounds only when the user explicitly asks.
- The current agent owns synthesis and next steps.
- Never ask the secondary CLI to call back into the primary CLI.
- Do not edit files during the review loop.
- Do not pass secrets, credentials, private production data, or sensitive customer data.

## Output contract

Secondary reviews should use:

```text
AGREEMENTS:
DISAGREEMENTS:
RISKS:
SUGGESTED CHANGES:
QUESTIONS:
```

Loop synthesis should end with:

```text
FINAL SYNTHESIS:
- What both agents agree on
- What changed in the plan
- Remaining disagreements
- User decisions needed
- Recommended next step
```

## CLI preflight

Before shelling out, verify the target CLI exists and is authenticated enough to run:

- Claude: `claude --version` and, when useful, `claude auth status`
- Codex: `codex --version` and, when useful, `codex exec --help`

If the CLI is missing, blocked, or unauthenticated, say so and perform a local
critique instead. Do not pretend another model reviewed the work.

## Runtime stance

- Claude review from Codex: prefer `claude -p --permission-mode plan`.
- Codex review from Claude: prefer `codex exec --cd "$PWD" --sandbox read-only`.
- Treat sandboxing and plan mode as defense in depth. The prompt still must say
  not to edit files or run write operations.
