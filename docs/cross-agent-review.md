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

When the secondary critiques a plan or proposal (an anchored review), it
should use:

```text
AGREEMENTS:
DISAGREEMENTS:
RISKS:
SUGGESTED CHANGES:
QUESTIONS:
```

Blind generative touchpoints (a parallel code review, security pass, or bank
audit) return the calling workflow's own findings format instead — there is
nothing to agree or disagree with.

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

- Claude review from Codex: prefer `claude -p --permission-mode plan < prompt-file`.
- Codex review from Claude: prefer `codex exec --cd "$PWD" --sandbox read-only -` (prompt via stdin — see Canonical invocation below).
- Treat sandboxing and plan mode as defense in depth. The prompt still must say
  not to edit files or run write operations.

## Canonical invocation

Real review prompts (a plan plus context) are long, and `codex exec` can hang
when a long prompt is passed inline as an argument. Always pass the prompt via
a temp file and stdin.

Shell state (variables, traps) does not survive across separate agent tool
calls — write the prompt file and launch the CLI in a **single shell
invocation**, and clean up explicitly afterwards. An `EXIT` trap is safe only
when set in the same invocation that runs the CLI; set in an earlier call it
fires before the CLI ever runs and deletes the prompt file.

Synchronous form (plan reviews — ask-codex, ask-claude, breakdown):

```bash
PROMPT_FILE="$(mktemp)"
cat > "$PROMPT_FILE" <<'EOF'
...the full prompt...
EOF

# Codex review from Claude:
codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
# Claude review from Codex:
claude -p --permission-mode plan < "$PROMPT_FILE"

rm -f "$PROMPT_FILE"
```

Background form (parallel touchpoints — review, security-check): stdout of a
bare `&` job is lost, so capture it to a second temp file and read that file
at merge time:

```bash
PROMPT_FILE="$(mktemp)"; OUT_FILE="$(mktemp)"
cat > "$PROMPT_FILE" <<'EOF'
...the full prompt...
EOF
codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE" > "$OUT_FILE" 2>&1 &
XAGENT_PID=$!
rm -f "$PROMPT_FILE"          # safe — the launched process already holds the file open
echo "$XAGENT_PID $OUT_FILE"  # note these — kill/read at merge time
```

If your harness has a native background-execution facility on its shell tool,
prefer it over bare `&` — it tracks completion for you. At merge time read
`$OUT_FILE`; if it's empty or incomplete after the timeout, proceed
single-model and kill the straggler (`kill "$XAGENT_PID"`). Clean up
`$OUT_FILE` after the merge.

The prompt file lives in the shared temp dir until cleanup — never write
secrets, credentials, or private data into it.

## Touchpoint patterns

Cross-agent calls aren't limited to plan review. When a workflow adds a
secondary-CLI touchpoint, follow these rules:

- **Blind over anchored.** When the secondary agent generates findings (a
  review, a risk list, an audit), give it the same inputs as the primary — not
  the primary's conclusions. Anchored critique tends to validate framing;
  independent generation surfaces blind spots.
- **Provenance tags.** Merged findings are tagged `[both]`, `[claude]`, or
  `[codex]` so agreement and disagreement stay auditable. The primary agent
  verifies secondary-only findings against the code before including them.
- **Hide the latency.** Launch the secondary CLI in the background while the
  primary does its own pass; merge at the end.
- **Offered vs. default-on.** Ambient touchpoints (e.g. the bank audit in
  update-memory) are offers the user can decline. Default-on is reserved for
  explicitly invoked scrutiny rituals (a code review or security check the
  user asked for) and the high-impact plan reviews recommended in `AGENTS.md`
  — and even then it is opportunistic: bounded timeout, skip on trivial
  input, never wait indefinitely.
- **Concentrate where self-grading is weakest.** Clean self-reviews, READY
  verdicts, empty risk sections, and the agent summarizing its own session are
  where a second model earns its cost.
- **Never block, never pretend.** If the secondary CLI is missing, slow, or
  unauthenticated, complete single-model and label the output accordingly.
