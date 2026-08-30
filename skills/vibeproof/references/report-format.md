# Report Format

`scoring_version: 2`

The same **confirmed finding set** always produces the same score. The score is
arithmetic over counted findings, never an impression.

It is *not* claimed that the same commit always produces the same score: working out
which promises an app makes is model reasoning, not parsing, so the finding set
itself can vary. Overstating that would be the same class of lie this tool exists to
catch.

---

## Three tracks, one verdict

The audit now covers more than promises, and a single number cannot carry that.
Three scores, each with its own arithmetic:

| Track | Covers | References |
|---|---|---|
| **Reality** | Does the product do what it says? | the five category files |
| **Security** | Is the trust boundary held? | `security.md` and what it routes to |
| **Health** | Will it keep working? | `dependencies.md` `injection.md` `reliability.md` `code-health.md` |

They are kept separate for one reason: **dilution**. Sixty maintainability notes
folded into the Reality Score would make the same number mean "this product lies"
and "this variable is badly named". A score that means two things decides nothing.

The **ship verdict is shared** — a blocker in any track blocks — and it is still
the only thing that decides whether to ship. Three scores, one decision.

```
REALITY  87/100  🟡 MOSTLY REAL
SECURITY 42/100  🔴 EXPOSED        ← 1 critical
HEALTH   71/100  🟠

SHIP VERDICT  ❌ DO NOT SHIP
```

Injection findings score into Security, not Health, when they are reachable with
user input — they are boundary failures. Unreachable ones stay in Health.

---

## Scoring

Each track starts at 100. Subtract per finding, within its own track:

| Severity | Penalty |
|---|---|
| 🔴 BLOCKER | −12 |
| 🟠 RISK | −4 |
| 🟡 CLEANUP | −1 |

Floor the result at 0. Do not round, weight, or "adjust for context". If the number
feels wrong, the findings are wrong — fix the findings, not the number.

Two rules on what gets counted at all:

- **One root cause = one scored finding.** A dead `Export` button that qualifies as
  Ghost UI *and* Fake Feature *and* Broken Wiring is one finding with one primary
  category and two tags. Three real defects must not read as nine.
- **`SUSPECTED` findings are not scored.** They can be listed as worth a look; they
  do not move the number.

**Reality Score bands:**

| Score | Band |
|---|---|
| 90–100 | 🟢 **REAL** |
| 75–89 | 🟡 **MOSTLY REAL** |
| 50–74 | 🟠 **VIBEY** |
| 25–49 | 🔴 **MOSTLY FAKE** |
| 0–24 | 🎭 **BEAUTIFUL LIE** |

## Ship verdict

The score never decides this. Evaluate **in order** and stop at the first match:

| # | Condition | Verdict |
|---|---|---|
| 1 | One or more verified BLOCKERs | ❌ **DO NOT SHIP** |
| 2 | A critical promise went untraced | ❔ **INCONCLUSIVE** |
| 3 | A layer required by an in-scope promise was unavailable | ❔ **INCONCLUSIVE** |
| 4 | A non-destructive build/typecheck exists but could not be verified | ❔ **INCONCLUSIVE** |
| 5 | No blockers, but verified risks exist | ⚠️ **SHIP WITH KNOWN GAPS** |
| 6 | No blockers, no risks, coverage sufficient | ✅ **SHIP** |

**Finding nothing is not the same as there being nothing.** Zero findings over a
third of the codebase is not a pass — it is an unfinished audit, and it says so.

A high Reality Score never overrides INCONCLUSIVE. Print the score anyway; it
describes what was examined, not what was concluded:

```
         REALITY SCORE  94/100
                🟢 REAL

         SHIP VERDICT  ❔ INCONCLUSIVE
         3 of 5 critical promises traced · backend not present
```

That report is *less* trustworthy for shipping than an 87/100 with full coverage and
two named gaps. Say so when it comes up.

Remember the blocker gate from SKILL.md: verified evidence, production-reachable,
user-visible, critical consequence, and a passed challenge. All five.

---

## Layout

```
╭──────────────────────────────────────╮
│              VIBEPROOF               │
│                                      │
│         REALITY SCORE  64/100        │
│                🟠 VIBEY              │
╰──────────────────────────────────────╯

18 product promises traced

  ✅  11  PROVEN
  ⚠️   2  UNPROVEN
  🎭   3  FAKE
  💥   2  BROKEN

  🔴  2 blockers    🟠 5 risks    🟡 9 cleanups
```

### Biggest Lie

The single finding where the gap between what the interface says and what the code
does is widest. One per report. **Always a verified BLOCKER** — never a `SUSPECTED`
or `PARTIAL` finding, however dramatic it would be if true. If there are no
blockers, omit the section entirely — do not promote something to fill it.

```
─────────────────────────────────────────
BIGGEST LIE
─────────────────────────────────────────

src/components/Profile.tsx:118

    deleteAccount(user.id);
    toast.success("Account deleted successfully");

The UI reports success unconditionally. deleteAccount() is async and is never
awaited, so the message fires whether the request succeeds, fails, or never
resolves. A user who sees this believes their account is gone.
```

### Findings

Grouped by severity, blockers first. Every finding carries a stable ID (`VP-001`)
so it can be referenced later: *"fix VP-003"*.

```
─────────────────────────────────────────
🔴 BLOCKERS
─────────────────────────────────────────

VP-001  False success on account deletion
        src/components/Profile.tsx:118
        [quoted code]
        [what is broken, in one or two sentences]
        Fix: await the call and branch on the result.

VP-002  Upgrade button links to a route that does not exist
        src/app/pricing/page.tsx:144  →  /checkout
        [quoted code]
        No page, route entry, or handler resolves /checkout.
        Nearest existing route: /pricing.
        Fix: create app/checkout/page.tsx or point the link at the real target.
```

Each finding: **ID · title · location · quoted code · what is broken · one-line fix.**
The fix is a direction, not a patch — VibeProof does not write code.

### Coverage

Mandatory. A score presented as covering more than it did is the same class of lie
this tool exists to catch.

```
─────────────────────────────────────────
COVERAGE
─────────────────────────────────────────
Files read              128 / 214
Promises traced          17 / 19
Critical promises         5 / 5      ← must be complete to SHIP
Runtime verified          4 / 19
Build                    ✅ ran, passed  (npm run build)
Tests                    ⏭️ no test script
Backend                  ✅ present in workspace
External payment         ⚠️ not executed (Stripe)

Not checked:
  • src/legacy/ — 34 files, excluded as unreferenced
  • admin console — separate repository, not present
```

State the scope at the start of the audit too, and never phrase conclusions as
though you examined more than you did:

```
AUDIT SCOPE   frontend ✅   api ✅   worker ✅
              mobile ✗ not present   billing → external boundary
```

### Trust Summary

End a full audit with what was actually done. This is more useful than a score:

```
─────────────────────────────────────────
TRUST SUMMARY
─────────────────────────────────────────
Runtime evidence          3 flows
Static evidence          14 flows
Partial                   2 flows
Critical promises         5 / 5 traced
Negative proofs           2 completed
Blockers challenged       1 / 1
External boundaries       Stripe (not executed)
Suppressed findings       0
```

Every line must be true of this run. A Trust Summary that overstates is worse than
no Trust Summary, because it is the section a reader uses to calibrate the rest.

---

## Feature mode

`/vibeproof feature <name>` traces one flow. No repository score — a single feature
does not have one.

```
AUTHENTICATION — REALITY

  Signup         ✅ PROVEN     form → /api/signup → users.create → session
  Login          ✅ PROVEN     form → /api/login → verify → session
  Logout         ✅ PROVEN     clears cookie server-side
  Reset password 🎭 FAKE       ResetForm.tsx:42 — success toast, no send call
  Email verify   ⚠️ UNPROVEN   token generated; consumer not found
  Admin guard    💥 BROKEN     app/admin/page.tsx — client-only check

2 of 6 steps do not do what the UI claims.
```

---

## Diff mode

`/vibeproof diff` audits only changed files. State the base explicitly, and score
only the changes — do not report a whole-repo score from a partial read.

```
VIBEPROOF · DIFF        main…HEAD        9 files changed

  🔴 1 blocker introduced
  🟡 2 cleanups introduced
  ✅ 1 previous finding resolved (VP-004)

VP-011  Success toast added before await
        src/features/billing/Checkout.tsx:71  (added in this diff)
```

---

## Tone

Blunt about the code. Never about the person.

- ✅ "The UI reports success before the request resolves."
- ❌ "Whoever wrote this clearly did not test it."

The findings are already uncomfortable. Editorialising makes them easier to dismiss,
which is the opposite of the goal.

Write in plain declarative sentences. No hedging ("it seems that possibly"), no
padding ("it is worth noting that"). State what is there, state what is missing.

---

## Shareable artifacts

Offer these at the end of a full run. Do not write files unless the user asks.

### Badge

Print a ready-to-paste snippet. Colour follows the band.

```markdown
![VibeProof](https://img.shields.io/badge/VibeProof-64%2F100_VIBEY-orange)
```

Colours: `brightgreen` REAL · `yellowgreen` MOSTLY REAL · `orange` VIBEY ·
`red` MOSTLY FAKE · `black` BEAUTIFUL LIE.

A badge is a claim the repo makes about itself, so it must be honest: only offer it
after a run whose coverage was complete enough to stand behind. If you read half the
files, say the badge would be misleading and skip it.

### Committed record — `VIBEPROOF.md`

On request, write the full report to `VIBEPROOF.md` in the repo root, with the commit
SHA and date at the top. Committing it turns each audit into a diffable record:
the next run's changes show up in `git diff`.

### Baseline — regression tracking

On request, write `.vibeproof/baseline.json`:

```json
{
  "scoring_version": 2,
  "commit": "a3f91c2",
  "date": "2026-08-30",
  "score": 64,
  "verdict": "DO_NOT_SHIP",
  "coverage": { "promises": [17, 19], "critical": [5, 5] },
  "findings": [
    { "id": "VP-001",
      "file": "src/components/Profile.tsx", "line": 118,
      "severity": "blocker",
      "product_status": "FAKE",
      "evidence": "STATIC_VERIFIED",
      "primary_category": "false-success",
      "related_categories": ["ghost-ui"],
      "promise": "Account deleted successfully",
      "broken_hop": "RESULT → SUCCESS DECISION",
      "root_cause": "unawaited-call",
      "challenge_passed": true,
      "fingerprint": "Account deleted successfully|RESULT→SUCCESS DECISION|unawaited-call|deleteAccount" }
  ]
}
```

`fingerprint` is `promise | broken_hop | root_cause | symbol` — deliberately **not**
line-based, so a finding survives unrelated edits that shift line numbers, and
deliberately keyed on the *cause* so the same defect cannot re-enter under a second
category. `product_status` and `evidence` are separate fields for the same reason
they are separate axes in the report.

Evidence belongs to a code state. If the implementation behind a finding changes,
the earlier verification is stale — re-verify rather than carrying it forward.
Yesterday's runtime proof is not proof of today's code.

When a baseline exists, `/vibeproof diff` reports movement instead of a flat list:

```
  🔴 1 introduced      VP-011
  ✅ 2 resolved        VP-004, VP-007
  ⏸️ 6 unchanged
```

"Introduced" is the number that matters in review — it answers *did this change ship
a lie?* without re-arguing findings the team already accepted.

---

## Output rules

- Plain text / markdown to the terminal. No file is written unless asked.
- Never print a secret value, token, key, or password — name the location and the
  kind only.
- If zero findings: say so plainly and show the coverage table. A clean report with
  honest coverage is a real result; inventing a finding to look useful is not.
