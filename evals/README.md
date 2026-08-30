# The VibeProof Corpus

A benchmark for fake-completeness failures in AI-generated apps.

Every fixture is a small, realistic snippet with its ground truth written down.
Every broken one is **paired with a control** that looks almost the same and is
correct.

---

## No numbers yet

There is no precision, recall, or false-positive rate published here, because no
recorded runs exist yet. When they do, the table below fills in from actual output.

A benchmark score invented to make a repository look rigorous is precisely the kind
of thing this tool was built to catch. It will stay empty until it is earned.

---

## Why every bug has a control

A detector that only ever sees broken code passes its own tests while flagging
everything in sight. "It found the bug" is not a result on its own — a tool that
reports every `toast.success` as false success also finds it.

The control is where precision is measured. So the pairs are built to be as close
together as possible:

| Control (correct) | Bug (broken) | The whole difference |
|---|---|---|
| `axios-default` | `axios-validate-status-disabled` | One line in a factory the call site never mentions |
| `broken-route-rewrite` | `broken-route-missing` | A `rewrites()` block in `next.config.js` |
| `fake-persistence-optimistic-rollback` | `fake-persistence-local` | Whether the rollback path exists |
| `false-success-awaited` | `false-success-unawaited` | One `await` and one branch |
| `dead-ui-honest-disabled` | `dead-ui-noop` | Whether the copy admits it |
| `eventual-consistency-honest` | `eventual-consistency-overclaimed` | "scheduled" versus "permanently deleted" — same backend |
| `secret-anon-key-client` | `secret-service-role-public-env` | Which key is behind the public prefix |
| `ownership-enforced-by-rls` | `missing-ownership-check` | A migration file the route does not reference |
| `vendor-import-not-residue` | `ai-residue-comments` | Whether the comment addresses a reader or a person |

Three of those controls are traps for specific, plausible mistakes:

**`broken-route-rewrite`** has no `app/checkout/` directory. A search that stops at
the filename declares the route missing and produces a confident blocker. Only the
`next.config.js` rewrite saves it — this is the fixture that tests
[negative proof](../skills/vibeproof/references/negative-proof.md).

**`ownership-enforced-by-rls`** has no ownership predicate in the handler, and is
correct anyway: the row-level policy enforces it in the database. Missing the
migration yields a false CRITICAL on an authorization finding, which is the most
damaging error the security mode can make.

**`vendor-import-not-residue`** mentions Anthropic four times, all legitimately — a
dependency, configuration, a genuine explanation, a model identifier. A cleanup
pass that matches on vendor names corrupts this file.

---

## Layout

```
evals/corpus/
  reality/    <fixture>/ expected.json + source
  security/   <fixture>/ expected.json + source
```

Ground truth, per fixture:

```json
{
  "id": "axios-validate-status-disabled",
  "family": "false-success",
  "kind": "bug",
  "pairs_with": "axios-default",
  "product_status": "FAKE",
  "evidence_max": "STATIC_VERIFIED",
  "severity": "risk",
  "primary_category": "false-success",
  "broken_hop": "RESULT -> SUCCESS DECISION",
  "requires": "reading the client factory, not the call site",
  "note": "validateStatus: () => true makes every response resolve..."
}
```

| Field | Meaning |
|---|---|
| `kind` | `bug` or `control` |
| `pairs_with` | The opposite fixture. Must be reciprocal |
| `product_status` | Expected status: `WORKING` `UNVERIFIED` `FAKE` `BROKEN`, or `SECURED` `MISCONFIGURED` `EXPOSED` |
| `evidence_max` | The **strongest** level a correct run may claim. Claiming more is a failure even if the finding is right |
| `must_not_report` | Categories that would be double-counting or a false positive |
| `expect_findings` | Exact count where it matters. Always `0` on a control |
| `requires` | What a run has to actually look at to get this right |

`evidence_max` deserves attention: a run that reports the right finding with
overstated evidence has failed. That distinction is the point of the whole trust
model, so the corpus scores it.

---

## Running it

Structural check — no agent needed, runs in CI:

```sh
sh evals/run-check.sh
```

It enforces that ground truth is declared, controls expect zero findings, pairing
is reciprocal, and bugs and controls stay balanced. It does **not** run VibeProof.

Running the actual audit needs an agent, so it is a manual loop:

1. Copy one fixture directory somewhere on its own.
2. `git init && git add -A && git commit -m fixture` — the tool expects a repo.
3. Run `/vibeproof` (or `/vibeproof security`) in Claude Code, Cursor or Codex.
4. Compare against `expected.json` and record the result.

Score each run on four axes, not one:

| | |
|---|---|
| **Detection** | Was the defect found at all? |
| **Category** | Primary category correct, and nothing from `must_not_report`? |
| **Severity** | Consequence-based, not category-based? |
| **Evidence** | At or below `evidence_max`? |

A control fails if it produces any finding.

---

## Cross-agent comparison

Results will differ between agents. That is data, not a defect to hide:

```
Fixture: axios-validate-status-disabled

  Claude Code   FAKE / STATIC VERIFIED     ✅
  Codex         WORKING                    ❌ missed the factory
  Cursor        FAKE / PARTIAL             ⬇ right finding, overstated as blocker
```

This is evaluation only. Three agents agreeing does not make a finding verified —
ground truth is the fixture, never a vote. Never combine weak guesses into a strong
claim.

---

## Adding a fixture

**No new detector without a negative control.** A contribution that adds "flag
every `toast.success` after a `fetch`" must also add the legitimate cases that must
not trigger: the axios default, the checked response, optimistic UI with rollback,
and fire-and-forget where the copy never promised completion.

1. Create `corpus/<area>/<id>/` with source files and `expected.json`.
2. Create the paired opposite. Keep the difference as small as you honestly can —
   a pair that differs in ten ways tests nothing in particular.
3. Run `sh evals/run-check.sh`.

Keep fixtures small. A fixture nobody can read in thirty seconds is one nobody will
maintain, and the value here is in the pairing, not the volume.
