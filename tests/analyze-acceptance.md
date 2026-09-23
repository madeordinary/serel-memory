# Analyze acceptance exercise

This exercise tests observable agent behavior. The automated parity and export
checks cannot establish that a prompt makes correct semantic judgments.

From the Memory checkout, create two independent fixtures:

```bash
exercise_root="$(mktemp -d)"
bash tests/prepare-analyze-fixture.sh "$exercise_root/claude"
bash tests/prepare-analyze-fixture.sh "$exercise_root/codex"
```

The builder copies only framework instructions and helpers, creates a synthetic
project with real git history, runs two tests at the initial revision, records
that result, then leaves a source change untested. It requires Git, Bash and
Python 3; the optional checker also needs jq. It refuses an existing target.
No private project content or fabricated verification SHA is used.

Open each fixture in its respective CLI and request `/analyze` or `$analyze`.
Use a fresh session with the CLI's read-only or plan mode. Give the agent only
the request, not this guide's expected findings. Do not run the tests again
during the audit, and do not let the audit edit the fixture.

Inspect both reports for these distinctions:

| Evidence in the fixture | Expected assessment |
|---|---|
| CSV exporter and test source exist; activeContext/progress still say implement it | Documentation drift; inspect current code without claiming a fresh test pass |
| Accepted TTL is 300; working-tree code says 30; test definition expects 300 | Possible regression requiring an owner decision; preserve accepted policy |
| A future desktop UI is explicitly unbuilt | Valid intent, not documentation drift |
| 10,000 tasks/second claim has no benchmark | Missing evidence, not proof that the claim is false |
| Historical kickoff entry says CSV was absent | Preserve the dated/historical context |
| Verification record predates a working-tree source change | Historical result, not verification of the changed code |
| Checker sees dirty evidence paths | Exit 2/incomplete; do not call this proven stale evidence or hide the failure |

Every finding should identify its bank location and source evidence. Both
reports should state inspected subjects and unassessed areas, propose follow-up
without writing it, and avoid a whole-bank correctness score.

Compare a before/after snapshot of **all fixture paths and bytes**, including
untracked files, to verify no writes. A clean `git diff` alone is insufficient:
the fixture starts dirty and a newly generated file may be untracked.

Also try a topic-only invocation and a scoped fixture. It should narrow the
claim set, honor explicit scope over cwd, and leave other banks unread. A
partial maintainer overlay must not fall back to tracked starter templates.
An uninitialized normal bank must stop and name the missing core files.

Record the CLI versions, fixture revision, reports, observed behavior, and
coverage limits in the maintainer's working bank when performing this exercise.
These are bounded acceptance observations, not a promise of identical wording
or correctness on every future run.
