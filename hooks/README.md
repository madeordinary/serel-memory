# basecamp hooks

These hooks make basecamp's `/start` and `/update-memory` flows happen automatically. They're **off by default** — you opt in per project.

## What's here

| File | Event | What it does |
|------|-------|--------------|
| `session-start.sh` | `SessionStart` | Reads the memory bank + `.rules` + recent git activity and injects it as session context. Replaces typing `/start`. |
| `pre-compact.sh` | `PreCompact` | Reminds the agent to refresh `activeContext.md` and `progress.md` before Claude Code compacts context. Replaces remembering `/update-memory`. |
| `enable-hooks.sh` | n/a | One-shot script that registers the two hooks above in `.claude/settings.json`. |

## Enable

```bash
bash hooks/enable-hooks.sh
```

Idempotent — safe to re-run. Requires `jq` for the JSON manipulation; if jq isn't installed, the script prints the settings.json block for you to paste manually.

After enabling, hooks fire on every Claude Code session in this project. No extra steps.

## Disable

**Temporarily** (current shell only):

```bash
export BASECAMP_HOOKS=off
```

Both scripts check this env var and exit early. Useful when you want to hack quickly without the bank getting touched.

**Permanently**: remove the basecamp entries from `.claude/settings.json`. Or delete the whole `hooks` object if you don't use any other hooks.

## When to enable

Enable on projects where:

- You come back to the project across many sessions
- Memory continuity matters more than ceremony
- You'd rather not type `/start` and `/update-memory` every time

Keep them off for:

- Quick exploratory hacking where the bank is overhead
- Throwaway scripts
- Projects where you specifically want the discipline of running the commands manually

## How they work

Claude Code's hook system lets you run shell commands at specific lifecycle events. Output to stdout is added to the model's context.

- `session-start.sh` runs once per Claude Code session, just after the agent boots. Its stdout becomes additional context the agent sees alongside `CLAUDE.md`.
- `pre-compact.sh` runs before context compaction (which happens automatically when context fills up or when the user runs `/compact`). Its stdout becomes the instruction the agent acts on during compaction.

The scripts read `$CLAUDE_PROJECT_DIR` (set by Claude Code) to anchor paths. If it's not set, they fall back to `$PWD`.

## Codex CLI?

Codex doesn't use Claude Code's hook system. For Codex users, `AGENTS.md` already instructs the agent to read the memory bank at session start, so the SessionStart equivalent happens by convention. There's no PreCompact equivalent in Codex — you'll have to run the `/update-memory` prompt manually before long sessions.

## Customizing

These are bash scripts. Open them, change them. Add your own hooks. If you write a hook that's useful enough that it belongs in basecamp, send a PR.
