# Active Context

> The most volatile file in the bank. Current focus, recent moves, next steps.
> Update at the end of every working session.

## Current focus

Iterating on basecamp's workflow kit — refining skill naming, adding upstream sync capability.

## Recent changes

- Dropped `basecamp-` prefix from all 12 Codex skills to match slash command naming
- Added `/sync-upstream` command and `$sync-upstream` Codex skill for framework updates
- Renamed `/plan` to `/breakdown` to avoid Claude Code plan mode conflict
- Added cross-agent second opinion workflow (`/ask-codex` / `$ask-claude`)
- Added `/from-prd` workflow with clarification checkpoint

## Next steps

1. Add Codex skills for workflows that only have slash commands (`/retro`, `/weekly-update`, `/runbook`, `/security-check`)
2. Consider reorganizing `docs/` so framework docs live under a dedicated path (Codex raised this)
3. Test `/sync-upstream` on a real downstream fork

## Open questions

- Should `AGENTS.md` and `CLAUDE.md` always require manual diff review during sync? (users are expected to customize these)
- Is the collision risk for generic skill names (`$start`, `$review`, `$ship`) acceptable, or should we document a namespacing convention for projects that add their own skills?

## Notes for next session

- All stale `$basecamp-*` references have been swept — verified with `rg`. Zero remaining.
- The sync-upstream command has two modes: fork mode (shared git history) and template mode (degit/unrelated history).
