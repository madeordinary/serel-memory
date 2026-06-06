# Improvement roadmap

**Date:** 2026-06-06 · **Derived from:** [deep research report](2026-06-06-repo-improvement-research.md)
(references like “→ C7” point at findings there)

Priorities at a glance: ship a provenance anchor and reposition the README now; build
the drift story next with a scoped plugin experiment alongside; converge on SKILL.md
and a thin installer once there's traction. Items trace to verified findings where
they can (references like → C7); items resting on unverified ground or plain local
hygiene are explicitly marked as such.

**Cross-agent review:** Codex (read-only, 2026-06-06) reviewed this plan against the
report, README, and AGENTS.md. Verdict: *ship with edits* — 10 findings (7 important,
3 minor), all incorporated below. Headline corrections: tighten provenance for
unpinned installs, don't market drift-check before it exists, scope MB1 down to a
prototype for solo-maintainer realism, and gate tiered reads behind an ADR.

---

## Quick wins (days, low risk)

### QW1 — Add a provenance anchor: `.basecamp.json`

Record the upstream repo + commit SHA a downstream project scaffolded from
(cruft `.cruft.json` / Copier `.copier-answers.yml` pattern → C7). degit runs no
hooks, so: (a) make the documented install command **pinned**
(`npx degit gusfeliciano/basecamp#v0.1.0`) followed by a one-liner that writes the
anchor for that tag, and (b) have `/sync-upstream` create the anchor retroactively on
first run (cruft-`link` pattern) — but mark retro-anchors as `"linked": true` rather
than claiming an exact source SHA that an unpinned copy can't actually know
*(Codex finding #1)*. **Prerequisite for MB2 and MB3.** Single highest-leverage cheap
port found in the research.

### QW2 — Reposition the README around the real differentiators

The bank structure is Cline-inherited (and already attributed), and bare "dual-CLI"
is advertised by the 58k-star incumbent (→ C3). Lead instead with what nothing else
ships **and basecamp has today**: cross-agent review, allowlisted `/sync-upstream`,
framework-integrity tests — and frame dual-CLI as *true symmetric parity* vs ruflo's
alpha-staged, Claude-first Codex support. Keep drift-check OUT of the README until
MB3 ships — present-tense copy only describes shipped features; the drift narrative
joins the launch story when it exists *(Codex finding #3)*. Re-check ruflo's Codex
maturity before publishing the comparison (→ §6 caveat).

### QW3 — Build the evidence pack (demo repo + recorded session)

A public demo repo plus an asciinema/GIF of a real session (`/start` reading the bank,
a `/breakdown` with cross-agent review) and exact reproduction prompts. This is the
explicit acceptance currency of awesome-claude-code (→ A2) and doubles as the README
hero and any launch-post material. Note the listing gates: **≥5 stars and ≥7 days
before submitting, web-UI issue form only — no PRs, no `gh` CLI** (→ A1).

### QW4 — CI hygiene: link checker + markdown lint

Add `lychee` (link check) and `markdownlint` jobs beside the existing
parity/allowlist/degit-smoke tests. *Marked as a bet:* standard practice, but the
testing-patterns angle produced no surviving verified claims (→ §6 gaps) — adopt
because it's cheap and reversible, not because the research proved it matters.

### QW5 — GitHub metadata pass *(local hygiene, not a research finding)*

Set the repo homepage URL (currently unset). **Hold `isTemplate: true` until QW1
lands**: GitHub template copies bypass degit and would ship with no provenance anchor
at all, undermining MB2/MB3 for exactly those users *(Codex finding #2)*. When the
button is enabled, document a mandatory first-run anchor step (`/sync-upstream` link)
for template users.

---

## Medium bets (weeks)

### MB1 — Plugin *prototype* first, full plugin only with parity CI

Target state: the 17 workflows + SessionStart/PreCompact hooks packaged with explicit
semver, `claude plugin validate`, submitted to `claude-plugins-community` (→ D1, D3,
D4), including a **`/basecamp:init` scaffold command** that writes templates from
`${CLAUDE_PLUGIN_ROOT}` into `${CLAUDE_PROJECT_DIR}` (developer-kit pattern → D2, D6).
Two Codex-flagged gates before going past prototype:

- **Parity (finding #5):** a plugin is a *third* maintained surface before ST2 removes
  duplication. Don't ship it without extending `tests/check-parity.sh` (or a sibling)
  to verify plugin command content against `.claude/commands/` — generated, not
  hand-copied. Start with a 2–3 command prototype + minimal marketplace submission to
  learn the screening policy (→ §7.1).
- **Scaffold safety (finding #6):** `/basecamp:init` writes into the user's repo —
  define acceptance criteria before shipping: explicit user consent prompt, refuse to
  overwrite existing files, write only the allowlisted template set, and document the
  behavior in `SECURITY.md`.
Known costs, verified: commands namespace as `/basecamp:*` (empirical test, §1) —
acceptable because degit installs keep the bare names and the two coexist;
third-party auto-update is opt-in per user (→ D3).

### MB2 — Split `/sync-upstream` into *check* + *pull*

A non-interactive, CI-runnable "are you behind upstream?" gate that exits 1 on drift
(cruft-`check` pattern → C7), reading the QW1 anchor; keep the existing interactive
allowlist-guarded pull as the apply step (cruft-`update` / Copier three-way-merge
analog). Gives downstream repos drift protection without manual checking — and gives
basecamp a "framework updates you can audit" story no competitor has.

### MB3 — Build `/analyze` drift-check (bank-vs-code)

**First-mover gap, verified: no competitor ships automated drift detection** (→ C6).
Design it on OpenSpec's archive-as-merge loop (→ C5): detect where code contradicts
bank claims → present the drift as a *delta proposal* against the bank → user approves
→ fold the accepted delta back into the bank files. The fold-back step is what
basecamp's manual "update memory bank" lacks. Pairs with MB2: one gate for framework
drift, one workflow for knowledge drift.
**Design guard (Codex finding #7):** "code differs from bank" is not always drift —
the bank also records *intent not yet built*. Drift proposals must classify each
flagged claim as **current fact / decision / intended-future / open question**, only
treat contradicted *current facts* as drift, and never write anything except diffs the
user reviewed. Otherwise the tool pressures users to erase intent — the exact opposite
of the bank's purpose ("the bank is the source of truth for what we *meant* to
build").

### MB4 — Tiered session reads *(ADR-gated; deferred trigger stands)*

Two independent validations confirm the *design*: Anthropic's native memory loads only
a 200-line/25KB index then reads topic files on demand (→ E3), and Roo's JIT
mode-isolation targets exactly the read-everything-at-start cost (→ C4). But this
changes basecamp's documented startup contract — AGENTS.md and the README both promise
"read these files, in this order, before doing anything else" — so it is bigger than a
workflow tweak *(Codex finding #8)*. Disposition: keep the original trigger ("defer
until a real project hits bank bloat"), and when it fires, do it as an ADR + prototype,
not an in-place edit. The research upgrades its *confidence*, not its *urgency*.
Adopt the pattern, **not** the unbenchmarked "~70% savings" number (→ C4 caveat).

---

## Strategic (months / post-traction)

### ST1 — Distribution endgame: hybrid now, thin installer later

The verified verdict is hybrid (plugin layer + degit layer → §1). The field norm one
level up is a versioned CLI installer with semver and documented upgrades —
`npx bmad-method install`, `openspec init`/`update` (→ C1). When traction justifies
maintenance, a thin `npx basecamp init` wrapper (degit + write `.basecamp.json` +
optional plugin pointer) subsumes the installer option at low cost. Keep the semver
release cadence started with v0.1.0 — 36 releases is part of how BMAD signals trust.

### ST2 — Converge both workflow trees on SKILL.md (open standard)

Agent Skills is an open standard (Dec 18, 2025) natively consumed by both target CLIs
(→ E4). Converging `.claude/commands` + `.agents/skills` into one portable tree would
collapse the parity-maintenance burden and make the plugin's content cross-tool. It is
a **migration, not a rename** (Claude flat commands → skills; invocation UX to test in
both CLIs) — prototype with 2–3 workflows before committing (→ §7.2).
**Exit criteria before deleting either tree** *(Codex finding #9)*: Claude invocation
UX unchanged (or consciously accepted), Codex invocation UX unchanged, session-start
loading behavior verified, plugin packaging still works, and parity CI rewritten for
the converged layout — all green, or no deletion.

### ST3 — Workflow consolidation via complexity gating, not deletion

The 17→~13 question resolves better as *mode-grouping/complexity-gating* (Roo's
Level-1-skips-planning routing; BMAD's persona/phase organization → C4) than as
removing workflows. No external evidence prescribes an ideal count — decide from
usage once real projects run on v0.1.0. Re-implement the pattern; Claude/Codex lack
Roo's native per-mode scoping mechanism.

### ST4 — Launch narrative and channel plan

Lead with the drift story (MB2+MB3) and symmetric dual-CLI depth (→ C3). The
launch-channel playbook itself (Show HN mechanics, subreddit norms, influencer
dynamics) is **unverified across two research rounds** (→ §4 gap) — treat channel
tactics as cheap experiments, not plans. Sequence that *is* evidence-backed: evidence
pack (QW3) → ≥5 stars + ≥7 days → awesome-claude-code web-form submission (→ A1, A2)
→ community-marketplace plugin listing (MB1) as a second discovery surface (→ D4).

---

## Explicit non-actions

- **No pure-plugin migration** — plugins can't scaffold project files or serve Codex
  (→ D2, D5).
- **No official-marketplace pursuit** — there is no application process; community
  tier is the route (→ refuted #2).
- **No copying Roo's "70% token reduction" claim** anywhere in docs/marketing —
  unbenchmarked (→ C4 caveat).
- **No docs site yet** — no verified evidence it matters at 0 stars; in-repo docs
  suffice until traction (→ §6 gaps).

## Suggested sequence (solo-maintainer realistic — Codex finding #10)

One core product bet (the drift story: MB2 → MB3) plus one scoped distribution
experiment (MB1 prototype) — not three medium bets in parallel:

```text
Week 1:    QW1 → QW2 → QW4 → QW5(homepage only)   (anchor, positioning, CI, metadata)
Week 2:    QW3                                     (demo repo + recording)
Weeks 3-5: MB2 → MB3                               (check/pull split, then drift-check
                                                    — the core differentiator bet)
Parallel:  MB1 as a 2-3 command prototype + marketplace-policy probe only
After:     ST4 launch push → full MB1 (with parity CI) → ST1-ST3 as traction warrants
Gated:     MB4 stays behind its bloat trigger + ADR
```

Cut order if time compresses (per Codex): MB4 first, then ST2, then ST1; protect
MB2+MB3 — they are the wedge.

*Companion artifact: [full cited research report](2026-06-06-repo-improvement-research.md).*
