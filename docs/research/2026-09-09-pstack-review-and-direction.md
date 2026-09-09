# pstack review and the Serel Memory direction (2026-09-09)

Maintainer research. Compares Cursor's `pstack` plugin (v0.15.0, MIT,
`cursor/plugins/pstack`) with Serel Memory v0.4.0, names what to adopt and
what to leave, and states how Serel Memory will work from here. Reviewed by
Codex (read-only, one round: REVISE, findings folded below). Downstream
projects are referred to generically; none are named.

## 1. What pstack is

pstack is an **execution-rigor layer** for Cursor: one sticky router skill
(`poteto-mode`, 142 lines) matches a task to one of 23 playbooks, copies the
playbook's steps into a todo list verbatim, and calls situational skills as
steps fire (`how`, `why`, `architect`, `arena`, `swarm`, `interrogate`,
`tdd`, `unslop`, ...). Twenty-three principle micro-skills (16–34 lines each)
are a steering vocabulary the reply must cite. Diversity comes from model
families, not personas; fan-out returns summaries, never raw payloads.

Its persistence is real but scattered and local by default:

- **Transcripts are the default substrate.** `recall`, `reflect`,
  `automate-me`, and `session-pickup` mine
  `~/.cursor/projects/<slug>/agent-transcripts/`. `recall` also sweeps the
  shared record (source control, issues, docs, error tracking); pickup
  accepts a pushed branch or a cloud-agent URL.
- **Decision trail per run.** `show-me-your-work` keeps a TSV
  (`ts, phase, decision, why, evidence, result`), local by default and
  committed when a reviewer needs it, audited against the transcript by a
  different model family at the end. `architect` ships design rationale
  with alternatives inside the diff.
- **The one worked cross-session state design is `orchestrate`'s store:**
  one writer per file, tables updated in place plus an append-only
  overview, a `status.md` *derived* at every drain and never hand
  maintained, verdicts keyed by PR + head SHA so a new SHA voids the row,
  standing orders re-supplied on every spawn because "directives decay
  across resumes", explicit restart recovery.
- **Planning exists as a playbook** (`multi-phase-plan`: a validated
  checkbox plan that waits for permission), not as a default; the README's
  "no planning skills" is the author's preference, not a missing capability.

## 2. What Serel Memory is, restated against that

Serel Memory is the **continuity layer**: what we meant to build, the
decisions that are settled, and where work stands, kept as plain Markdown
*in the repository*, owned by the project, diffable, identical for Claude
Code and Codex. A sync updates the *framework* files through an allowlist
that structurally cannot touch project memory.

**Complementary core, overlapping workflows.** The bank, its promotion
conventions, CLI parity, scoped banks, retention, and controlled framework
updates have no pstack equivalent. But several of our 17 workflows overlap
pstack's, and for someone already running pstack they may be redundant:
`/breakdown` ↔ `multi-phase-plan` / `figure-it-out`, `/review` ↔
`interrogate`, `/retro` ↔ `reflect`, `/handoff` ↔ `pause-safely` +
`session-pickup`, `/ask-codex` ↔ a second-model pass. The comparison should
establish which of ours earn their place, not defend all of them.

## 3. Side by side

| Concern | pstack | Serel Memory v0.4.0 | Verdict |
|---|---|---|---|
| Session start | `recall` (transcripts + shared record), `session-pickup` | `/start` reads the 7-file bank + `.rules`; SessionStart hook; `## Checkpoint` | Ours is portable and repo-owned. Adopt pickup's pairing: the prior trail is authoritative for *reasoning and completed investigation*; inherited *completion claims* are verified on the real artifact. |
| Clean stop | `pause-safely`: stop at a boundary, `wip:` commit, resume note; explicitly NOT on "keep going" | pre-compact hook + Checkpoint | **Adopt with limits** (§5.3). No blanket wip commits. |
| Durable decisions | per-run rows; rationale in diffs; no project-wide register | `decisionLog.md` + ADRs, supersede-don't-delete | Keep. **Adopt** *decision / why / evidence / result* as a compact entry shape that keeps date, status, and supersession links; ADR alternatives and consequences stay. |
| In-flight audit trail | TSV per run, cross-model audit | bank-vs-reality audit in `/update-memory` | Different questions (process audit vs bank truth). Trail deferred (§6). |
| Learning capture | `reflect` diagnoses whether existing guidance triggered before adding more; `encode-lessons-in-structure` routes recurring fixes to mechanisms, keeps judgment rules as prose with an example | `.rules` journal → `systemPatterns` promotion | **Adopt** as a trigger to investigate, not a mandate (§5.2). |
| Review | `interrogate`: same prompt to N models; agreement is confidence metadata; lead judgment protects lone correctness/security findings; never auto-apply | `/review` blind dual-model pass; `/security-check` already weights consensus; `VERDICT` contract | **Adopt** explicit disagreement reporting. Evidence and impact decide action, not votes. |
| Drift / staleness | `maintain-verification-skill`: per-feature readers → reconcile → live re-prove → whole-run `clean/changed/blocked`; doc drift kept distinct from product regression | MB2 (planned) | **Adopt the loop shape and the drift-vs-regression distinction**, not the per-run vocabulary (§5.5). |
| State keyed to reality | `orchestrate` ledger keyed by SHA; derived `status.md` | `progress.md` prose | **Adopt for MB2 as opt-in evidence markers** with explicit semantics (§5.5). |
| Workflow structure | 1 router + 23 playbooks loaded on match | 17 self-contained pairs + contract doc | **Pilot**, don't migrate (§5.1). |
| Config | per-role model rule, whole-file idempotent rewrite, `auto`/`inherit-parent` | `.serel-memory.json`, in-place `jq` update | Keep. |
| Framework sync | Benny pack: verify each file landed in a **fresh session**, preserve unrelated settings | allowlist, fork/template modes, anchor | Ours is stronger; **borrow** fresh-context install verification for sync and future plugin packaging. |
| Multi-project | none | scoped banks, explicit bank-selection contract | Ours. |
| App verification, prose tools | `create-verification-skill`, `unslop`, `technical-writing` | none | Out of Memory's scope; their principles can still improve our own tests and docs. |

## 4. Not adopting, and why

- **Transcript mining as a substrate.** Cursor-specific paths; sessions in
  Claude Code and Codex differ and can be purged. An optional, scoped
  *import* from a transcript is a separate future possibility.
- **Principle leaf skills.** Not a retention-budget question (selectively
  loaded files cost nothing at rest); it is citation overhead and value.
  AGENTS.md's four "Making changes" principles stay inline.
- **Sticky mode and verbatim todo copying** are Cursor runtime metadata.
  *Explicit routing and step checklists* are portable and judged on their
  own in §5.1.
- **Per-role model config.** Out of scope for a continuity layer; our
  no-model-pinning policy stands.
- **N-model fan-out.** A cost/scope limit, not a parity consequence: two
  CLIs, one blind pass each, graceful single-model fallback.
- **"Never block on the human" as a default.** Bank writes stay gated by
  show-diffs-first (pstack's `reflect` gates skill edits the same way).

## 5. How Serel Memory will work from here (v0.5 direction)

Identity, in one line: *the repo-owned continuity layer for coding agents,
CLI-neutral, diffable, framework-synced, bounded (retention), and
multi-project (scopes).* Everything below serves that line, and the order
is: prove today's product downstream, then the checker, then structure.

**5.0 First: the real downstream sync and a small demo.** Run
`/sync-upstream` in the two owner-controlled downstream repos to pull
v0.4.0 — the first real delta the procedure has ever faced — and fix what it
gets wrong. Record a short demo of today's product (start, update-memory
with retention, scoped banks, the verdict loop), all synthetic. Extend the
demo when MB2 exists.

**5.1 Thin entry points: pilot, then decide.** Pick two or three pairs —
one simple (`/ship`), one complex and asymmetric (`/ask-codex` ↔
`$ask-claude`), one memory-writing (`/update-memory`) — and move their
procedure into a single canonical file each (not one growing contract),
leaving the adapters as trigger, scope, required reads, allowed writes,
output contract, stop conditions, and a pointer. Measure with pstack's
eval lesson: realistic prompts, both CLIs, blinded judgment, evidence of
which files were actually read. The tests need extending first:
check-parity compares paired files and selected strings, not behavior, and
its invocation-safety scan skips the contract; smoke tests extract
executable snippets *from the adapters*. Only if the pilot shows equal or
better procedure-following does the rest migrate. 17→13 remains a usability
question the pilot informs but does not settle.

**5.2 Learning routing.** `/update-memory` step 5 and `/retro`: when a
`.rules` entry is about to be written a second time, or a correction
recurs, first ask why the existing guidance did not take (did it trigger?
was it already there? wording or placement?), then propose the structural
form (test, hook check, CI step). Keep the prose rule until the mechanism
exists and works; judgment rules stay prose with a concrete failure
example.

**5.3 Clean stop.** pre-compact and `/update-memory` gain: finish or back
out of the current atomic step; the Checkpoint records HEAD, dirty state,
what is verified, and the first action on resume. A `wip:` commit only on
an actual pause the user asked for, and only over authorized, owned
changes — never on compaction, never on "keep going".

**5.4 Review synthesis and entry shape.** `/review` and `/security-check`
print one line per explicit contradiction between the two passes; silence
is not disagreement. Agreement is confidence metadata; evidence and impact
decide. `decisionLog.md` entries use *decision / why / evidence / result*
while keeping date, status, and supersession; an accepted-but-unbuilt
decision records `result: pending`.

**5.5 MB2, the deterministic checker (next substantive feature, no
refactor prerequisite).** `serel-memory check [--scope <path>]`, exit
`0 clean / 1 drift / 2 audit-failed`, read-only, CI-runnable downstream.
Scope of what it can honestly decide:

- framework/anchor drift (allowlisted files vs the anchor's `ref`;
  legacy-anchor guard; scopes config validity);
- retention targets (rotate-check on both files, per scope);
- declared paths: files, directories, and commands the bank names exist;
- explicitly labeled evidence: a claim carrying `verified: <sha> <paths>`
  is reported as *fresh* or *stale since <sha>* based on whether the named
  paths changed; a SHA without paths is decorative and ignored; dirty
  worktrees and unavailable revisions are reported as *incomplete*.

Unannotated prose is **unassessed**, never "clean". Output per finding:
*drift*, *stale*, *incomplete*; exit 1 only on drift or stale. Dates versus
`git log` are advisory hints, not findings. Absorbs the sync check/pull
split and the scoped-bank pilot's staleness ask.

**5.6 MB3, semantic `/analyze` (advisory).** Fact / decision / intent /
open-question classification, already prototyped in the bank-vs-reality
audit; presents each discrepancy as *documentation drift* or *possible
regression* for the owner to judge, never rewriting intent to match a broken
implementation.

**5.7 Deferred.** An optional per-run decision trail (gitignored by
default, outside routine bank reads, durable conclusions promoted into the
bank by hand) if autonomous runs become common. `/commit` does not earn a
place in a continuity release; revisit with the plugin work. Tiered session
reads stay ADR-gated, decided on MB2's data. The projector-contract bundle
preempts everything when a concrete compatibility claim appears.
Distribution endgame unchanged (plugin for the workflow layer, degit + sync
for the repo layer), with fresh-session install verification borrowed from
pstack's automation pack.

## 6. Owner questions, with the recommendation

1. **Thin entry points: one PR or slices?** Slices. Pilot two or three
   pairs, measure in both CLIs, then decide whether the rest earns its cost.
2. **`verified:` markers: opt-in or convention?** Opt-in per claim, with
   explicit paths. No annotation means unassessed, not failed.
3. **Runs trail in the bank or local?** Defer. If added, gitignored by
   default and outside routine reads; commit deliberately when auditability
   must travel; retention does not rotate arbitrary TSVs.
