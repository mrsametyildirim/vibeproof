# Report Format

Two people running VibeProof on the same commit must produce the same score.
The score is **arithmetic over counted findings**, never an impression.

---

## Scoring

Start at 100. Subtract per finding:

| Severity | Penalty |
|---|---|
| 🔴 BLOCKER | −12 |
| 🟠 RISK | −4 |
| 🟡 CLEANUP | −1 |

Floor the result at 0. Do not round, weight, or "adjust for context". If the number
feels wrong, the findings are wrong — fix the findings, not the number.

**Reality Score bands:**

| Score | Band |
|---|---|
| 90–100 | 🟢 **REAL** |
| 75–89 | 🟡 **MOSTLY REAL** |
| 50–74 | 🟠 **VIBEY** |
| 25–49 | 🔴 **MOSTLY FAKE** |
| 0–24 | 🎭 **BEAUTIFUL LIE** |

**Ship verdict** is decided by blockers alone — a score cannot override it:

- **1 or more BLOCKERS** → ❌ **DO NOT SHIP**
- **0 blockers, 1+ risks** → ⚠️ **SHIP WITH KNOWN GAPS**
- **0 blockers, 0 risks** → ✅ **SHIP**

Remember the constraint from SKILL.md: only a **PROVEN** finding may be a BLOCKER.

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
does is widest. One per report. Always a BLOCKER. If there are no blockers, omit the
section entirely — do not promote something to fill it.

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
Files read           128 / 214
Promises traced       18 / 18
Build                 ✅ ran, passed  (npm run build)
Tests                 ⏭️ not run (no test script)

Not checked:
  • server/ — separate repo, not present
  • src/legacy/ — 34 files, excluded as unreferenced
  • external URLs — not verified by design
```

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

## Output rules

- Plain text / markdown to the terminal. No file is written unless asked.
- Never print a secret value, token, key, or password — name the location and the
  kind only.
- If zero findings: say so plainly and show the coverage table. A clean report with
  honest coverage is a real result; inventing a finding to look useful is not.
