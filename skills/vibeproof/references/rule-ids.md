# Rule IDs and Suppression

A **finding ID** names an occurrence: `VP-014`, this problem in this file today.
A **rule ID** names the pattern: `VP-FS-001`, success reported before the result
was checked, anywhere, ever.

Findings are renumbered every run. Rule IDs never change. That difference is what
makes suppression, regression tracking and eval fixtures possible at all.

---

## The families

Deliberately few. A hundred rule IDs would mean a hundred detectors, which is the
direction this tool is explicitly not going.

### Reality

| ID | Pattern |
|---|---|
| `VP-FS-001` | Success reported before the result is checked |
| `VP-FS-002` | `catch` path reports success |
| `VP-FS-003` | Promise wording overclaims the guaranteed stage (*deleted* vs *scheduled*) |
| `VP-GU-001` | Interactive control with no meaningful handler |
| `VP-GU-002` | Navigation entry to a destination that does not resolve |
| `VP-BW-001` | Frontend route has no resolver |
| `VP-BW-002` | Client calls an endpoint that does not exist |
| `VP-FP-001` | Change never leaves the client |
| `VP-FP-002` | Delete only filters a local collection |
| `VP-HD-001` | Production path serves hardcoded data as if it were live |

### Security

| ID | Pattern |
|---|---|
| `VP-SC-001` | Server-only secret reachable in the client bundle |
| `VP-SC-002` | Secret committed to git history |
| `VP-SC-003` | Sensitive value flows to a logging, analytics or third-party sink |
| `VP-AZ-001` | Authenticated but no ownership check |
| `VP-AZ-002` | Identity, role or price taken from the request |
| `VP-AZ-003` | Enforcement exists only in the client |
| `VP-SB-001` | Row-level security not enabled on a table |
| `VP-SB-002` | Policy permits every row |
| `VP-SB-003` | Scoped policy over a row that carries other people's data |
| `VP-SB-004` | Policy covers `select` but not the operation the app performs |
| `VP-ST-001` | Public bucket holding non-public content |
| `VP-ST-002` | Private bucket with no owner-scoped policy |
| `VP-AI-001` | Model output treated as an authorization decision |
| `VP-AI-002` | Model-callable tool without its own permission check |
| `VP-AI-003` | Untrusted content reaches a model that can act |
| `VP-AI-004` | Sensitive data sent to a model provider, or model output rendered as HTML |
| `VP-DP-001` … `VP-DP-007` | Deployment and transport — see `deployment.md` |
| `VP-SH-001` | Conversational residue in shipped source |
| `VP-SH-002` | Invisible or bidirectional characters in source |

A rule ID is not a severity. `VP-GU-001` on a theme toggle is a cleanup; the same
rule on *Delete account* is a blocker. Consequence decides, every time.

---

## Suppression

Some findings are correct and the team has decided to live with them. Without a way
to say so, the report is noisy on the second run and ignored on the third.

The rule that keeps this from becoming an escape hatch:

> **A suppression hides a finding. It never turns it into WORKING.**

### `.vibeproofignore`

One suppression per line: rule, path or symbol, and a reason.

```
# rule            target                         reason
VP-HD-001         src/marketing/pricing.ts       prices are a fixed public catalogue
VP-DP-003         scripts/local-proxy.ts         dev-only; not reachable in production
VP-SB-002         supabase/migrations/004.sql    `listings` is a public catalogue by design
```

Three requirements:

**Narrow.** A rule and a target. Never a bare rule (`VP-HD-001` everywhere), never
a bare directory (`src/`). A suppression that covers code nobody has looked at is
indistinguishable from not running the tool.

**Reasoned.** The reason column is not optional, and for anything that would have
been critical it must say why the consequence does not apply — not that it is
inconvenient.

**Visible.** Every report states the count and lists them on request:

```
SUPPRESSED   3 findings   (.vibeproofignore)
             VP-HD-001 src/marketing/pricing.ts
             VP-DP-003 scripts/local-proxy.ts
             VP-SB-002 supabase/migrations/004.sql
```

Suppressed findings do not affect the Reality Score and do not appear in the
findings list. They **do** appear in the count, and they never change a verdict
from `DO NOT SHIP` to `SHIP` silently. If suppressing something would flip the
verdict, say that in the report:

```
SHIP VERDICT  ⚠️ SHIP WITH KNOWN GAPS
              Would be ❌ DO NOT SHIP without 1 suppression (VP-AZ-001).
```

That line is the difference between a suppression file and a lie.

### Inline

For a single line, where a file-level entry would be too broad:

```js
// vibeproof-ignore VP-HD-001 — sample data for the empty state, not a live feed
const PLACEHOLDER_ROWS = [ ... ];
```

Same three requirements. A bare `// vibeproof-ignore` with no rule and no reason is
ignored — it suppresses nothing, and the report says so, because a comment that
silences everything on a line is how suppression stops meaning anything.

---

## Why not just delete the finding

Because the next audit finds it again, and the run after that, and eventually
someone adds a directory to a config file to make the noise stop. That directory
then hides a real finding a year later, and nobody remembers it is there.

A suppression with a rule, a target, a reason and a visible count is a decision
that stays reviewable. That is the whole difference.
