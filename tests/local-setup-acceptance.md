# Local setup acceptance exercise

`tests/smoke-install.sh` proves the installer's mechanics. It cannot show that
Claude Code and Codex discover Git-excluded workflows, read a Git-excluded
bank, route a blank bank to setup, or stop at a project scope of a local
install. This exercise checks that in fresh sessions. Nothing here has been
observed until someone runs it and records the result.

From the Serel Memory checkout, build one fixture per CLI and variant:

```bash
exercise_root="$(mktemp -d)"
for cli in claude codex; do
  for variant in team fresh blank scoped; do
    bash tests/prepare-local-setup-fixture.sh "$exercise_root/$cli-$variant" "$variant"
  done
done
```

Each fixture is a synthetic git repository with staged, unstaged and
untracked work, and a local install made by `install.sh --local --apply` from
this checkout. An uncommitted checkout gives a linked anchor, which is
expected. The variants:

| Variant | Instruction files | Bank |
|---------|-------------------|------|
| `team` | tracked team `AGENTS.md` and `CLAUDE.md`; no local `AGENTS.md` | seeded, focus token `LEDGER-LITE-7731` |
| `fresh` | none tracked; a local, Git-excluded `AGENTS.md` | seeded, same token |
| `blank` | none tracked; a local `AGENTS.md`; code plus `docs/spec.md` | blank templates |
| `scoped` | as `fresh`, plus tracked code in `projects/example/`; the local anchor lists `"scopes": ["projects"]` | root seeded, same token; no `projects/example/memory-bank/` |

`scoped` needs `jq`. Its scopes were added after the install, as a user might
add them by hand, so the exclusions cover only the root `memory-bank/` and
`.rules`: a bank under `projects/example/` would be visible to Git.

Before each session, snapshot every file, ignored ones included, and Git's view:

```bash
snap() {
  (cd "$1" && find . -path ./.git -prune -o -type f -exec cksum {} + | LC_ALL=C sort &&
    GIT_OPTIONAL_LOCKS=0 git status --porcelain --ignored --untracked-files=all)
}
snap "$exercise_root/claude-team" >"$exercise_root/claude-team.before"
```

Open each fixture in its CLI in a fresh session, in read-only or plan mode.
Give the agent only the request below, not the expected results.

1. **Discovery.** In Claude Code, type `/` and look for the project commands
   (`/start`, `/init-memory`, ...). In Codex, use `/skills` or type `$`.
   Record whether the Git-excluded workflows are listed.
2. **Start.** Run `/start` or `$start`.
   - `team` and `fresh`: the audit lists the seven bank files and `.rules`,
     and the summary reports the `--since` focus and token `LEDGER-LITE-7731`.
     The working tree shows only the fixture's own `expenses.csv`,
     `ledger.sh` and `scratch.txt` changes, never the installed files.
   - `blank`: start switches to setup mode, asks only what it could not
     detect, one question per message and at most four (none is needed about
     code or the spec, which are both detectable; the installed Serel Memory
     scripts are not counted as code), and its `SETUP PLAN` names
     `/init-memory` with `docs/spec.md` as planned intent. It writes nothing
     and waits.
   - `team` or `fresh` with `/start setup`: start enters setup mode although
     the bank is initialized, reports it as initialized, and never offers to
     re-seed it.
3. **Local install at a project scope** (`scoped`). Run each of these in its
   own fresh session:
   - `/start --scope projects/example` (Codex: `$start --scope projects/example`)
   - `/start setup --scope projects/example`
   - `/init-memory --scope projects/example`, and one of `/discover` or
     `/from-prd` with the same `--scope`, invoked directly without `/start`

   Each resolves the scope first, detects the local install, and stops before
   any setup plan, question about the project or proposal. It says the local
   install keeps only the root bank and `.rules` out of Git and that scopes
   listed later do not extend that, and offers the root bank (`--scope .`) or
   a shared, committed install. It writes nothing: no
   `projects/example/memory-bank/`, and `info/exclude`, `.gitignore`, the
   anchor and the instruction files are unchanged. A plain `/start` at the
   repository root reads the root bank (token `LEDGER-LITE-7731`) and lists
   `--scope projects/example [uninitialized]` without reading anything there.
4. **Instructions.** In `team`, the agent must not edit `AGENTS.md` or
   `CLAUDE.md`; record whether the CLI loaded the team instructions on its
   own. In `fresh`, open another fresh session and ask "What is this
   project's current focus?" without `/start`, and record whether the CLI
   loaded the Git-excluded `AGENTS.md` by itself. Claude Code's `AGENTS.md`
   fallback needs v2.1.277 or later and no `CLAUDE.md`; when it is not
   loaded, `/start` remains the documented entry point.

After each session, snapshot again and compare with `diff`. They must be
identical: a read-only session writes nothing, and the install stays
invisible to Git.

Record the CLI versions, fixture variant, whether discovery and bank reading
worked, the setup recommendation, and any write, in the maintainer's working
bank. These are bounded observations, not a promise of identical wording or
behavior in every future CLI release.
