# Deep research: improving basecamp as an open-source repo

**Date:** 2026-06-06 · **Status:** complete · **Companion:** [improvement roadmap](2026-06-06-improvement-roadmap.md)

> **Historical naming:** this report predates the Serel Memory rename. Basecamp
> product and plugin names below are preserved as the terminology evaluated on
> the report date; current repository references use
> `madeordinary/serel-memory`.

**Question.** What should basecamp improve, adopt, or steal to be a better open-source
repo — for the maintainer's own use, for people starting new projects from it, and for
attracting outside users and contributors? Primary sub-question: the distribution
endgame (degit + sync-upstream vs Claude Code plugin vs both vs something else).

**Method.** Two adversarially-verified deep-research workflow runs on 2026-06-06
(210 subagents total; 46 sources fetched; 230 claims extracted; the top 50 put through
3-vote adversarial verification — each claim attacked by three independent skeptics,
≥2/3 refutations kill it). Result: 45 claims confirmed, 5 killed. Plus one local
empirical test of plugin command namespacing. GitHub star counts were verified live via
the GitHub API on 2026-06-06, not taken from blogs.

Confidence notation: votes like **3-0** mean three verifiers each tried and failed to
refute the claim.

---

## 1. Verdict on the primary question: hybrid, not migration

> **Do both, in layers.** (1) Package the 17 workflows + 2 hooks as a `basecamp`
> Claude Code plugin with explicit semver, validate with `claude plugin validate`,
> submit to the community marketplace. (2) Keep degit + `/sync-upstream` as the
> canonical full-framework install for the memory-bank templates, `.rules`, and the
> CLAUDE.md/AGENTS.md layer — the parts plugins structurally cannot ship — optionally
> adding a plugin-shipped scaffold command so plugin-first users can bootstrap without
> degit. (3) Strategically, evaluate converging both workflow trees on the open
> SKILL.md standard, and adopt tiered/lazy bank reads.
>
> Pure-plugin migration is ruled out by the scaffolding gap and the dual-CLI design;
> pure-degit status quo forfeits a verified, high-traction discoverability and
> auto-update channel.

### Supporting findings (round 1, all high confidence)

**D1 — The whole Claude-side surface fits in one plugin** (3-0, merged from 3 claims).
The plugin component model covers skills (including flat `.md` commands), agents,
hooks, MCP servers, LSP servers, and more; plugin hooks support exactly the
`SessionStart` and `PreCompact` events basecamp uses. The 17 workflows and both hooks
fit with no architectural change.
Sources: [plugins-reference](https://code.claude.com/docs/en/plugins-reference),
[plugins](https://code.claude.com/docs/en/plugins),
[discover-plugins](https://code.claude.com/docs/en/discover-plugins).

**D2 — A plugin cannot replace degit for the project-file half** (3-0, merged from 5
claims). A `CLAUDE.md` at plugin root is *explicitly not loaded* as project context;
marketplace plugins install to a user-level cache (`~/.claude/plugins/cache`), cannot
reference files outside their directory, and the documented component model has **no
install-time mechanism for scaffolding files** (memory-bank templates, `.rules`,
`AGENTS.md`) into a user's repo. Shipping those requires a runtime command that writes
templates from `${CLAUDE_PLUGIN_ROOT}` into `${CLAUDE_PROJECT_DIR}` — a workaround, not
a documented mechanism. developer-kit hit the same wall (its README tells users to copy
rules manually or via Makefile); open issue anthropics/claude-code#21163 requests a
`rules` field in plugin.json. Note: a skill conversion of CLAUDE.md content is
lazy-loaded, not always-in-context — a SessionStart hook is the closer substitute.

**D3 — Plugins win on upgrade ergonomics for the workflow layer** (3-0, merged from 4
claims). Version resolves from plugin.json semver (the version is the cache key);
`claude plugin update` / startup auto-update deliver new versions; explicit semver
means downstream users only receive changes when the maintainer bumps the field.
Caveats: auto-update is on by default **only for official Anthropic marketplaces**
(off for third-party — a basecamp plugin needs a one-time per-user opt-in or manual
`/plugin update`), and known cache bugs (#44276, #46081, #33653) can delay or skew
update detection.

**D4 — The marketplace channel has real, verified discoverability** (3-0, merged from
4 claims). `claude-plugins-official` is pre-installed in every Claude Code
installation — verified live 2026-06-06: **29,506 stars / 3,168 forks**, created
2025-11-20, pushed same day — with in-product `/plugin` → Discover browsing and
one-command install. Inclusion in the *official* tier is at Anthropic's discretion
with **no application process**; third-party submissions land in
`anthropics/claude-plugins-community` via in-app forms
(claude.ai/settings/plugins/submit), validated with `claude plugin validate` plus
automated safety screening, pinned to commit SHAs with CI auto-bumping. Caveat: users
must add the community marketplace manually — zero-step discoverability applies only to
official-tier inclusion.

**D5 — Anthropic's official guidance maps plugins onto basecamp's goals** (3-0, merged
from 2 claims) — community sharing, versioned releases, cross-project reuse,
marketplace distribution — while positioning standalone `.claude/` config (basecamp's
current form) for single-project personal use. But the plugin mechanism is **Claude
Code-only**: a plugin covers only the Claude half of the dual-CLI design. Qualifier:
skill *content* inside a plugin can be reused cross-tool via SKILL.md; the
packaging/marketplace/install mechanism cannot.

**D6 — The hybrid model is proven in the wild** (3-0).
[developer-kit](https://github.com/giuseppe-trisciuoglio/developer-kit) ships as a
Claude Code plugin marketplace *and* supports Codex CLI, OpenCode CLI, and Copilot CLI
via parallel Makefile installers (`make install-codex` writes skills to
`~/.codex/skills/` plus a generated AGENTS.md index) — verified at implementation
level (Makefile targets real, marketplace.json valid, v3.0.1 released 2026-06-06).
Corroborated by a second project (EveryInc/compound-engineering-plugin). Qualifiers:
cross-CLI install is lossy, and this proves *feasibility*, not adoption success
(~270 stars).

**D7 — Basecamp's upgrade story already beats the directly-comparable competitor**
(3-0, merged from 2 claims).
[hudrazine/claude-code-memory-bank](https://github.com/hudrazine/claude-code-memory-bank)
(Cline-style bank for Claude Code) distributes via manual clone/copy, has zero
releases/tags (4 commits, dormant ~10 months, 39 stars), no versioning or upgrade
path. Market-signal caveat: that competitor is marginal — an existence proof of the
low-tech path's ceiling, not strong evidence about what winning projects do (see §3
for what winning projects actually do).

### Empirical test: plugin command namespacing (local, 2026-06-06)

The round-1 verifiers killed (1-2) the claim that plugin commands are mandatorily
namespaced — the docs don't settle it. A local test settled it empirically. Minimal
plugin `bcptest` with command `pingtest.md`, loaded via `claude --plugin-dir`:

| Invocation | Result |
|---|---|
| `claude -p "/bcptest:pingtest"` | ✅ command executed |
| `claude -p "/pingtest"` | ❌ `Unknown command: /pingtest` |

A basecamp plugin's commands would register as `/basecamp:start`, `/basecamp:breakdown`,
etc. (at least in print mode; interactive autocomplete may soften the typing cost).
**Implication: the hybrid gets cleaner** — plugin = namespaced + auto-updating;
degit = bare `/start` names living in the repo. The two can coexist without collision.

---

## 2. Ecosystem shifts: what obsoletes basecamp, what amplifies it

**E1 — The CLAUDE.md → `@AGENTS.md` import is platform-sanctioned** (3-0). Claude Code
does not read AGENTS.md natively (feature requests with thousands of reactions remain
open as of June 2026), and Anthropic's
[memory docs](https://code.claude.com/docs/en/memory) recommend *exactly* the pattern
basecamp ships: a CLAUDE.md that imports AGENTS.md so both tools share one instruction
file. Risk note: community pressure means native AGENTS.md support could land later.

**E2 — Native auto memory complements, doesn't obsolete, the bank** (3-0). Auto memory
(on by default since v2.1.59) is stored machine-locally in
`~/.claude/projects/<project>/memory/`, explicitly "not shared across machines or cloud
environments," never repo-committed by default. A repo-committed, team-shareable,
agent-agnostic bank occupies a niche the platform does not cover; Anthropic's docs call
the two "complementary memory systems." Qualifier: `autoMemoryDirectory` can redirect
storage, so "not committed" is default behavior, not a hard constraint.

**E3 — Anthropic's own memory design validates the deferred tiered-reads plan** (3-0).
Native auto memory loads only the **first 200 lines or 25KB** of MEMORY.md at session
start, keeps it as a concise index, and reads topic files on demand. The
always-loaded-index + lazily-read-detail-files pattern is exactly the design basecamp
deferred. Validation is convergent, not an endorsement — Anthropic arrived at the same
pattern independently.

**E4 — Agent Skills is an open standard with real cross-tool adoption** (3-0).
Published by Anthropic as an open standard on **December 18, 2025**
([announcement](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills));
natively consumed by OpenAI Codex (developers.openai.com/codex/skills), Gemini CLI,
Cursor, Copilot, and others under open governance (agentskills.io). Since both of
basecamp's target CLIs natively consume SKILL.md, the dual `.claude/commands` +
`.agents/skills` trees could converge on a single portable tree. Verifier nuance:
basecamp's parity pairs Claude slash *commands* (not skills) with Codex skills, so
convergence is a **migration, not a rename**, with invocation-UX implications to test.

---

## 3. Competitive landscape (round 2)

**C1 — The winning distribution pattern is a versioned CLI installer** (3-0 each for
BMAD and OpenSpec). [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD):
`npx bmad-method install`, v6.8.0 on npm (2026-05-25), 36 GitHub releases, dedicated
upgrade docs. [OpenSpec](https://github.com/Fission-AI/OpenSpec):
`npm install -g @fission-ai/openspec`, `openspec init`, and `openspec update` which
*regenerates* AI-tool configuration after a CLI upgrade, v1.4.1 (2026-06-03). Both are
CLI-installer + semver — not degit-style file copy. The copy-paste-distributed
frameworks (Cline, Roo — see C6) are the pattern basecamp's degit already improves on;
the CLI installer is the pattern that wins above it.

**C2 — The category has overwhelming proven demand; basecamp is pre-launch at 0 stars**
(3-0, 3-0, 2-1). Verified live 2026-06-06: BMAD-METHOD **48,682 stars**; OpenSpec
**53,208 stars** (created 2025-08-05 — ≈175 stars/day for ~10 months);
ruvnet/claude-flow — 301-redirects to **ruvnet/ruflo** (renamed Jan 2026 over an
Anthropic trademark) — **58,219 stars**, pushed same day. The 2-1 split was only on the
"by far highest-traction" superlative; the numbers are unanimous-grade. These are
category benchmarks, not basecamp comparables.

**C3 — Two of basecamp's headline differentiators are weaker than assumed** (3-0 on
ruflo dual-CLI; 2-1 on Cline inheritance). (a) The 7-file bank is openly inherited from
Cline's 6-file pattern — basecamp's own README attributes it ("borrowed from cline's
memory bank... which is excellent but Cline-specific"); the bank *structure* is not a
differentiator. (b) Dual-CLI Claude+Codex support is already advertised by the
highest-traction competitor: ruflo's GitHub description ends "native Claude Code /
Codex Integration," and `@claude-flow/codex` exists on npm (3.0.0-alpha.12,
2026-05-17) with `init --codex` and a `$skill-name` syntax mirroring `/skill`.
**The opening that remains:** ruflo's Codex support is alpha-staged and shallower than
its Claude support — exactly the depth/quality gap basecamp can exploit with true
symmetric parity. Basecamp's genuine differentiators sit *above* the bank: cross-agent
review, allowlisted sync-upstream, framework-integrity tests, and (if built) automated
drift-check. The 2-1 split reflects that the inheritance claim doesn't negate overall
value — it just removes the bank structure from the differentiator list.

**C4 — Tiered context loading and complexity-gated workflows are proven, stealable
patterns** (3-0 across four sub-claims).
[roo-advanced-memory-bank](https://github.com/enescingoz/roo-advanced-memory-bank):
JIT mode-isolation ("Only the active custom mode's rules are loaded") and
complexity-gated routing (Level 1 tasks: VAN→IMPLEMENT; Levels 2–4:
VAN→PLAN→CREATIVE→IMPLEMENT). BMAD: 12+ role personas, 34+ agile-phase workflows,
Party Mode. Roo Code's 4–5 modes autonomously update the bank on mode-specific
triggers. Relevance: (1) consolidate basecamp's 17 workflows by
complexity-gating/mode-grouping rather than 1:1 deletion; (2) basecamp's
read-all-8-files-at-session-start is precisely the bloat these designs target.
Caveats: the lineage's "~70% token reduction" figure is aspirational and unbenchmarked
— adopt the pattern, not the number; and Claude Code/Codex lack Roo's native per-mode
rule scoping, so basecamp must re-implement the *pattern*, not copy the mechanism.

**C5 — OpenSpec's staged-change loop is the strongest model for `/analyze` drift-check**
(3-0). The propose → apply → archive loop creates a change folder (proposal, delta
specs, tasks), implements it, then **folds delta specs back into the main specs** as
the source of truth ("Specs are now the updated source of truth"). Nuance: the literal
default profile has 5 commands and the actual merge is `/opsx:sync` (archive invokes
it) — "three-stage" is OpenSpec's own headline simplification. Steal for drift-check:
model drift as a *delta against the bank*, let the user agree, then fold the accepted
delta back in — the archive-as-merge step is the "close the loop" piece basecamp's
manual "update memory bank" lacks.

**C6 — No competitor ships automated drift detection** (3-0). Cline's update model is
purely trigger-based ("update memory bank" triggers a full review; activeContext
"every few sessions") — the same manual pattern basecamp uses. A DeepWiki sweep of
official cline/prompts found "zero instances of the word drift"; a search snippet
mentioning drift detection traced to a third-party variant, not official. **An
automated `/analyze` drift-check would be a genuine first-mover differentiator.**
Also verified here (3-0 each): Cline and Roo Code distribute via copy-paste (no CLI,
no package, no installer) — confirming the distribution weakness basecamp's degit +
sync-upstream already improves on.

**C7 — The Python template ecosystem solved upgrade provenance with a tiny metadata
file** (3-0 across four sub-claims). [Cruft](https://github.com/cruft/cruft)'s
`.cruft.json` records template URL + git commit hash (retroactively attachable via
`cruft link`); [Copier](https://copier.readthedocs.io/en/stable/updating/)'s
`.copier-answers.yml` records answers + template version. Upgrade primitives worth
porting: **`cruft check`** — a non-interactive exit-code-1 CI gate that validates
whether a project is on the latest template version ("can be added to CI pipelines to
ensure projects don't unintentionally drift"); **`cruft update`** — non-destructive
diff-old→new, review-before-apply, then metadata rewrite; Copier's update is the same
idea as a three-way merge with pre/post-migrations. **Basecamp's degit copy currently
has no provenance anchor — adding one (e.g. `.basecamp.json` with the upstream commit
SHA) is the single highest-leverage cheap port and the prerequisite for any real
upgrade or drift gate.** Note: cruft uses a per-file *skip* list vs basecamp's
*allowlist*; the review-before-apply flow is directly analogous anyway.

---

## 4. Adoption & discoverability

**A1 — awesome-claude-code is a meaningful but tightly-gated channel** (3-0, 3-0).
Verified live 2026-06-06: **45,846 stars / 3,999 forks**. Submissions MUST use the
GitHub web-UI issue form — PRs and the `gh` CLI are explicitly disallowed; bypassing
risks a temporary/permanent ban. Acceptance gates: **≥5 stars, ≥7 days since first
commit, ≥14-day-old account, non-crypto**. Basecamp at 0 stars cannot list yet.
Caveat: the repo is mid-reorg (README "Update in progress," pushed 2026-04-27 —
~6 weeks stale at research time).

**A2 — Submissions must be evidence-based and reproducible** (3-0). The maintainer's
CONTRIBUTING is explicit: claims must be evidence-based; a video demo is "tremendously
helpful"; "Install this library... and watch the magic happen — no. Clone this demo
repository and install the plugin; give Claude the following prompt: ... — yes."
Do-this: pair any submission with a public demo repo + exact onboarding prompt (e.g.
"run `/start`") or an asciinema/GIF of a session reading the bank, plus
framework-integrity test output as reproducible proof. The same framing serves the
README and any launch post.

**Gap (honest):** the broader launch-channel playbook — Show HN timing/mechanics,
r/ClaudeAI / r/ChatGPTCoding norms, X dev-influencer dynamics, launch case studies for
spec-kit/task-master/claude-flow/BMAD, GitHub topics/SEO, docs-site-vs-in-repo impact —
produced **no surviving verified claims across two rounds**. Those domains are
judgment territory, not verified-fact territory; treat any tactic there as a bet.

---

## 5. Refuted claims — do not rely on these

Killed by adversarial verification (≥2/3 refutations):

1. ~~Plugin commands are mandatorily namespaced per docs~~ (1-2) — the docs don't
   establish it. *Settled empirically instead: namespacing is real in practice (§1).*
2. ~~You can apply for official-marketplace listing~~ (1-2) — there is **no
   application process**; official inclusion is at Anthropic's discretion. The
   community marketplace is the realistic route.
3. ~~Plugins have no mechanism for Codex parity or seeding files~~ (1-2 as stated) —
   the claim bundled a wrong premise; the verified versions are D1/D2.
4. ~~ruflo ships a 4-channel hybrid distribution (curl|bash + 33-plugin marketplace +
   MCP)~~ (1-2) — distribution specifics didn't survive; only the npm + dual-CLI facts
   did.
5. ~~Roo Code memory bank uses near-identical filenames to basecamp's~~ (1-2) — the
   precise filename list didn't survive; don't cite it.

---

## 6. Caveats and limits

- **Time-sensitivity.** Plugin-mechanics findings rest on official docs fetched live
  2026-06-06; the plugin system launched ~Oct–Nov 2025 and churns. Version-management
  details, marketplace policy, and the third-party auto-update default could change
  within months. Star counts drift ~100–175/day in this category — treat as
  order-of-magnitude signals.
- **Source concentration.** Plugin findings draw heavily on code.claude.com docs
  (technical reference, corroborated via GitHub API and bug trackers), but
  doc/behavior divergence is real — bugs #44276/#46081/#33653 show updates can lag.
- **Load-bearing item to re-check before acting:** ruflo's Codex support is alpha and
  shallow *today* but actively developed — the depth gap basecamp plans to exploit
  could close.
- **Editorial phrases** inside findings ("more mature," "same weakness") survived
  voting as defensible judgments, not hard facts.
- **Remaining gaps** (no surviving verified claims after two rounds): launch-channel
  mechanics and case studies; GitHub topics/SEO; spec-kit's `specify init`/upgrade.md
  specifics; claude-task-master / agent-os profiles; prompt-regression evals
  (promptfoo), link checkers, markdown linting, golden-file scaffold tests. The lost
  2026-05-30 audit is therefore only partially re-covered — strongest on distribution
  and ecosystem, weakest on launch tactics.

## 7. Open questions carried forward

1. Community-marketplace policy toward framework-style plugins that scaffold project
   files at runtime — would `/basecamp:init` pass automated safety screening?
2. Does Codex CLI (or agentskills.io governance) plan a plugin/marketplace-equivalent?
   Does migrating `.claude/commands` to SKILL.md preserve invocation UX in both CLIs?
3. How do spec-kit, task-master, and agent-os actually distribute/version (gap above)?
4. Which launch tactics correlate with traction for agent-tooling repos (unverifiable
   this round — judgment territory)?
5. Positioning: which remaining differentiator leads the README and launch narrative —
   cross-agent review, allowlisted sync-upstream, integrity tests, or drift-check?

## 8. Source quality summary

Primary sources (official docs, repos, registries, live GitHub API): code.claude.com
plugin/memory docs; anthropic.com Agent Skills announcement; agents.md;
anthropics/claude-plugins-official; BMAD-METHOD, OpenSpec, ruvnet/ruflo, cline docs,
GreatScottyMac/roo-code-memory-bank, enescingoz/roo-advanced-memory-bank,
hudrazine/claude-code-memory-bank, developer-kit, hesreallyhim/awesome-claude-code
(+ its CONTRIBUTING/ISSUE_TEMPLATE), cruft, Copier docs, github/spec-kit upgrade.md,
release-please, promptfoo, lychee-action, npm registry records. Secondary/blog sources
were used for leads and corroboration only; no finding above rests solely on a blog.

---

*Generated from two deep-research workflow runs (wf_6fa2db8a, wf_d26c05df) +
local empirical testing, 2026-06-06. Stats: 210 agents, 46 sources, 230 claims
extracted, 50 adversarially verified → 45 confirmed / 5 killed.*
