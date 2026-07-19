#!/usr/bin/env bash
# Serel Memory PreCompact hook
#
# Fires before Claude Code compacts session context. Reminds the agent to
# update the memory bank so this session's work isn't lost when older context
# is summarized away.
#
# To disable temporarily: export SEREL_MEMORY_HOOKS=off
# To disable permanently: remove from .claude/settings.json

set -euo pipefail

if [ "${SEREL_MEMORY_HOOKS:-}" = "off" ]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# If Serel Memory isn't installed here, do nothing
if [ ! -d "$ROOT/memory-bank" ]; then
  exit 0
fi

cat <<'EOF'
## Serel Memory: pre-compact memory bank refresh

Context is about to be compacted. Earlier conversation history will be summarized
and details may be lost. Before that happens, refresh the memory bank so this
session's work is preserved:

Note: if `memory-bank.local/` exists (upstream Serel Memory development), it is the
effective bank — apply all of the updates below to `memory-bank.local/` and its
`.rules`, never to the tracked starter templates.

1. Update `memory-bank/activeContext.md` to reflect:
   - Current focus
   - Recent changes (top of the list, most recent first)
   - Next steps
   - If multi-session work is underway, the `## Checkpoint` section — one
     resumable state (branch, what's done, exact next step), overwritten
     in place
   - Any new open questions

2. Update `memory-bank/progress.md`:
   - Move items from "in progress" to "what works" if they shipped
   - Add new known issues
   - Update the phase if it changed

3. Update `memory-bank/decisionLog.md` if a durable architectural, product,
   workflow, or operational decision was made.

4. If anything non-obvious was learned this session — a user preference, a
   gotcha, a rejected approach worth remembering — append it to `.rules`.

Show the diffs to the user and ask for confirmation before writing. Then proceed
with the compaction.
EOF
