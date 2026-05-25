# Progress

> Honest status. What works, what doesn't, where we are overall.
> Update when something ships, breaks, or changes status.

## Status

**Phase:** building

## What works

- Memory bank template files (7 core files + `.rules`)
- 17 Codex skills with matching slash commands (full parity, bare names)
- 17 Claude Code slash commands
- Cross-agent review workflow (Claude ↔ Codex)
- Optional hooks (session-start, pre-compact) for both tools
- `/sync-upstream` for pulling framework updates into downstream projects

## In progress

- (none currently)

## What's left to build

- Test sync-upstream on a real downstream project
- Consider `docs/basecamp/` reorganization for cleaner framework/project separation

## Known issues

- `codex exec` with long prompts can hang on stdin; piping works as a workaround

## Recent milestones

- Full Codex skill parity — all 17 workflows have both slash commands and skills (2025-05-25)
- Dropped `basecamp-` prefix from all Codex skills (2025-05-25)
- Added sync-upstream command with fork/template mode detection (2025-05-25)
- Added cross-agent second opinion workflow (2025-05-21)
- Added `/from-prd` with clarification checkpoint (2025-05-21)
