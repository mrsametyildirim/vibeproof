---
name: vibeproof
description: Audit an AI-generated app for fake completeness — features that look finished in the UI but are not actually wired to anything. Traces every user-visible promise from the button to the database and back. Use when asked to run /vibeproof, to check if an app is really done, to find fake or dead UI, unwired buttons, false success messages, or state that does not survive a refresh. Read-only; never modifies code.
---

# VibeProof

Linters inspect your code. VibeProof inspects your **product promises**.

The failure mode this skill exists for is not a bug. It is a **lie**: a button that
looks clickable and does nothing, a toast that says "Saved" before the request
resolves, a chart drawn from a hardcoded array, a form that updates React state and
loses it on refresh. The code has no syntax error. The linter is happy. The app is
not done.

Your job is to find the gap between **what the interface promises** and **what the
code actually delivers** — and to prove every claim you make.

---

## The one rule that makes this tool worth trusting

> **A finding without quoted evidence is not a finding. Delete it.**

You are auditing someone's work and telling them not to ship. That claim must be
verifiable in seconds. For every single finding you must have:

1. A real `path/to/file.ext:LINE` you actually opened and read
2. The **actual source line(s)**, quoted verbatim — not paraphrased, not reconstructed
3. The specific broken link in the chain, named

If you cannot produce all three, the finding does not go in the report. A tool that
cries wolf gets uninstalled after one run. **Under-reporting is recoverable;
false accusation is not.**

Never guess a line number. Never describe code you did not read. If you suspect
something but cannot open the file, say so in the Coverage section instead.

---

## Never modify anything

VibeProof is **read-only**. Do not fix, refactor, add, or delete a single line —
not even an obvious one-character fix, not even if asked politely mid-run.

The auditor who also patches loses the ability to be trusted about what was broken.
The user fixes things afterwards in a separate, explicit request
(`fix VP-004`), so the diff is theirs and the audit stays a record.

If the user asks you to fix something during a run: finish the report first, then
treat fixing as a new task.

---

## Procedure

### Step 1 — Detect the product

Before looking for problems, understand what the app claims to be. Read, in order:

- `README`, `package.json`/`pyproject.toml`/`go.mod` (name, scripts, deps)
- Route definitions / page files / app directory
- Component files that render user-visible text

Produce a short **Product Contract**: what kind of app this is, its user flows, and
its visible claims (button labels, toast strings, menu items, headings).

This step is what separates VibeProof from a linter. You are not scanning for
patterns — you are building a list of **promises the app makes to a human**, then
checking each one.

Do not skip this. A finding that is not tied to a user-visible promise belongs in
the Cleanups bucket at most.

**Mark the critical promises explicitly.** A promise is critical when getting it
wrong costs money, data, access, or trust:

- payment and billing
- destructive operations and account deletion
- authentication and authorization
- saving important user data
- upload
- irreversible external actions

```
CRITICAL           NORMAL
[C1] Delete account       [N1] Change theme
[C2] Upgrade subscription [N2] Sort projects
[C3] Save billing details [N3] Collapse sidebar
```

This split is what justifies tracing some flows to the end while sampling others —
and **every critical promise must be traced before you may issue SHIP.**

### Step 2 — Trace each promise

For every promise, follow the chain and find where it stops:

```
UI ELEMENT → HANDLER → CLIENT CALL → SERVER ROUTE → VALIDATION
          → PERSISTENCE → RESPONSE → UI FEEDBACK
```

Walk it in code. Use grep/search to follow each hop by name. Record the exact hop
where the chain breaks, or confirm it completes.

A chain is **complete** only if the persisted result could survive a page refresh.
Local state that never leaves the browser is not persistence.

Classify the promise on **two independent axes**. These answer different questions
and must never be collapsed into one label.

**Product status** — what the code does:

| Status | Meaning |
|---|---|
| ✅ **WORKING** | The chain completes |
| ⚠️ **UNVERIFIED** | Not enough of the chain could be checked to make a claim |
| 🎭 **FAKE** | The UI promises an effect; the code demonstrably produces none |
| 💥 **BROKEN** | The chain points at something missing, invalid, or unreachable |

**Evidence level** — how well you know it:

| Evidence | Meaning |
|---|---|
| ● **RUNTIME VERIFIED** | Observed by actually running something and reading the result |
| ◉ **STATIC VERIFIED** | Every necessary hop traced in source or config, nothing executed |
| ◐ **PARTIAL** | Real evidence exists, but at least one necessary hop is unconfirmed |
| ○ **SUSPECTED** | Pattern-level suspicion only |

A feature can be genuinely `FAKE` with only `PARTIAL` evidence, or `WORKING` with
merely `SUSPECTED` evidence. Those are different statements about different things.
The old single-axis model conflated them, which is why the blocker rule used to read
strangely — "only a PROVEN finding may be a BLOCKER" was mixing a product claim with
an evidence claim.

Two consequences:

- `SUSPECTED` findings **do not affect the Reality Score.** They may be mentioned as
  things worth a look; they are not counted.
- `PARTIAL` findings may be reported and scored, but can **never** be a BLOCKER.

Never write `RUNTIME VERIFIED` unless a command or flow actually ran and you read
the result. Static inspection that merely looks conclusive is `STATIC VERIFIED`.

When torn between `UNVERIFIED` and `FAKE`, choose **UNVERIFIED**. Uncertainty is a
fact about your evidence, not about their code — report it as such.

**Findings that rest on absence** — "no route", "no handler", "nothing consumes
this" — must satisfy `references/negative-proof.md` before they may be `BROKEN` or
`FAKE`. Not finding something is a fact about your search until the search was
thorough enough to be worth reporting.

### Step 2b — One root cause, one finding

The five categories overlap on purpose: they describe the same product failure from
different angles. A dead `Export` button is arguably Ghost UI *and* a Fake Feature
*and* Broken Wiring.

> **One root cause = one scored finding.**

Pick the single category that best describes *why* it is broken, record the others as
tags, and score it once. A user with three real defects should not see a score that
implies nine.

Identify a finding by:

```
promise + broken hop + root cause + symbol
```

Not by line number — line numbers move for unrelated reasons.

### Step 3 — Run the category checks

Five categories, detailed in `references/`. Read the reference file for a category
before reporting findings in it.

| Category | What it catches | Reference |
|---|---|---|
| 🎭 Fake Features | Hardcoded data, no-op handlers, mock responses in product paths | `fake-features.md` |
| 🔌 Broken Wiring | Missing routes, handlers, endpoints, dead links | `broken-wiring.md` |
| 🤥 False Success | Success reported before/despite failure | `false-success.md` |
| 💾 Fake Persistence | Changes that do not survive a refresh | `persistence.md` |
| 💀 Ghost UI | Rendered controls that connect to nothing | `ghost-ui.md` |

Three more reference files are not category checks but gates on what you are allowed
to claim:

| Reference | Applies to |
|---|---|
| `false-positives.md` | **Every finding, before it is written** |
| `negative-proof.md` | Any finding that rests on something being absent |
| `challenge.md` | Every proposed BLOCKER, before it is published |

Security mode adds more, all routed from `security.md`:
`secrets-and-egress.md` · `authorization.md` · `platform-supabase.md` ·
`llm-boundary.md` · `deployment.md` · `source-hygiene.md` · `fix-prompts.md` ·
`rule-ids.md`

**`false-positives.md` is not optional.** Most bad audits come from flagging test
fixtures, Storybook stories, seed scripts, and intentional demo modes.

One correction to how that file is often read: a path like `examples/`, `demo/`,
`scripts/`, `tools/` or `bin/` **lowers suspicion — it does not grant exemption.**
`bin/` can be the shipped product. Before suppressing on location alone, ask whether
the code is imported by production code, exposed as a route, invoked by a production
script, packaged, or part of the real user flow. If any is true, the suppression is
wrong. Tests, generated artifacts and vendored third-party output stay strongly
excluded.

### Step 4 — Verify what you can actually run

If a build/test/typecheck command exists in the project's manifest, run it and
report the real result. A failing build outranks every other finding. Running
something is the only way to earn `RUNTIME VERIFIED`.

**Safe to run without asking:** build, typecheck, lint, existing unit and
integration tests, local dev checks whose intent is clear from the manifest.

**Never run automatically:** deploy, publish, database migrations or resets, seeds,
billing actions, cloud mutations, anything that emails or messages real people, and
anything requiring production credentials. An unknown command is not assumed safe.

If proving a boundary would require a destructive or externally mutating command,
mark that boundary `UNVERIFIED` and move on. Do not report "build passes" unless
you ran it. Say "not run" instead.

**External boundaries.** Many promises end outside the repository — Stripe, Clerk,
Supabase, S3, a queue, a webhook. Finding an SDK call proves a call site exists. It
does not prove the external effect happened. Report those separately:

```
Internal chain    ◉ STATIC VERIFIED   button → /api/checkout → stripe.sessions.create
External effect   ⚠️ UNVERIFIED       Stripe interaction not executed
```

An unverified external boundary is not itself a finding. But if it sits on a
critical promise, the run cannot honestly end in SHIP — see the verdict rules in
`references/report-format.md`.

### Step 5 — Report

Show the **Product Contract first**, before any finding.

This is not decoration. Seeing the tool correctly identify their app — its flows,
its promises, in its own vocabulary — is what earns the reader's attention for the
findings that follow. A list of grep hits reads as noise; the same list under
"here are the 18 things your app promises a user" reads as an audit.

Then stream findings as you confirm them rather than holding everything to the end.
The trace is the interesting part: watching a promise get followed from a button to
a missing route is more convincing than being handed a verdict.

Use `references/report-format.md` exactly. Score is arithmetic, not judgement — see
the formula there. The same confirmed finding set always produces the same score.
Working out *which* promises exist is reasoning rather than parsing, so do not claim
the same commit always scores the same; it is not something this tool can guarantee.

**Finding nothing is not the same as there being nothing.** If critical promises
went untraced, a required layer was unavailable, or coverage was otherwise thin, the
verdict is ❔ **INCONCLUSIVE** — not SHIP. A high Reality Score never overrides
incomplete coverage. Saying "I could not verify this" is the tool working correctly.

---

## Severity

Severity comes from **consequence to a user**, never from how the pattern looks.
Category does not determine severity. The same technical defect changes severity
entirely depending on what it is attached to:

| Same defect | Attached to | Severity |
|---|---|---|
| Dead button | "Change theme" | 🟡 CLEANUP |
| Dead button | "Delete account" | 🔴 BLOCKER |
| Unchecked request | analytics preference | 🟠 RISK |
| Unchecked request | followed by "Payment complete" | 🔴 BLOCKER |

| Level | Test |
|---|---|
| 🔴 **BLOCKER** | Users lose data, lose money, or are told something happened that did not |
| 🟠 **RISK** | Feature silently fails or degrades |
| 🟡 **CLEANUP** | Ugly but harmless |

Weigh reversibility, data loss, financial consequence, auth impact, external side
effects, and whether the path is reachable in production.

### The blocker gate

A BLOCKER requires **all five**:

1. Evidence is `STATIC VERIFIED` or `RUNTIME VERIFIED`
2. The path is reachable in production
3. A real user sees the promise
4. The consequence is critical
5. It survived a challenge pass — `references/challenge.md`

Fail any one and it is at most a RISK. A `SUSPECTED` or `PARTIAL` finding can never
be a BLOCKER no matter how bad it would be if true.

The challenge pass is the important one: after writing a blocker, deliberately try
to disprove it. The first pass searched for evidence the finding is *true*, which is
precisely the search that misses the rewrite rule making it false. Report withdrawn
findings rather than quietly dropping them.

---

## Modes

| Command | Scope |
|---|---|
| `/vibeproof` | Whole repository — does it actually work? |
| `/vibeproof diff` | Only what changed vs. the default branch (`git diff`) |
| `/vibeproof feature <name>` | One flow, traced end to end |
| `/vibeproof security` | Is it safe to ship? — see `references/security.md` |
| `/vibeproof health` | Will it keep working? — dependencies, injection, reliability, code health |
| `/vibeproof all` | Everything, one report. The pre-launch pass |
| `/vibeproof security verify <id>` | Re-check one security finding against current code |
| `/vibeproof security clean` | Source hygiene only. The one command that writes |

`diff` mode is the one to use in a PR: it answers "did this change ship a lie?"
rather than re-litigating the whole codebase.

In `feature` mode, output the per-step table for that flow (see report format) and
skip the repository-wide score — a single feature does not have one.

---

## Scope

**In scope:** does the product do what its interface says it does.

**Also in scope**, on the Health track — the goal is one report a reader can act on
without opening a second tool:

| Reference | Covers |
|---|---|
| `dependencies.md` | Known vulnerabilities and supply chain. **Findings here only ever come from a tool that was actually run** — a CVE recalled from memory is fiction |
| `injection.md` | SQL, command, path, SSRF, XSS, open redirect, mass assignment |
| `reliability.md` | Unbounded queries, N+1, missing timeouts, races, rate limiting |
| `code-health.md` | Only what hides a defect, disables a safety net, or is a landmine |

**Still out of scope:** formatting, import order, file length, comment density,
coverage percentage as a target, and opinions about folder structure. Those are a
formatter's job, and putting them in a report trains the reader to skim past the
finding that stops a release.

The discipline that makes breadth survivable is **rationing**. `code-health.md`
lists what meets its bar and counts the rest:

```
CODE HEALTH   4 findings · 61 style observations not listed
```

### Security

`/vibeproof` and `/vibeproof security` are two halves of one question, and they
share this file's evidence rules, severity model and INCONCLUSIVE gate rather than
restating them:

```
does it actually work?   →  /vibeproof
is it safe to ship?      →  /vibeproof security
```

A dead button lies about what the product does; a client-side admin check lies
about who it lets in. Both are gaps between a visible promise and the actual
implementation, which is why they belong to the same tool.

The security mode is still **not** a general scanner. It targets how apps built by
Claude, Cursor, Lovable, Bolt and Replit actually fail: a service key behind a
public env prefix, an endpoint that checks login but not ownership, a storage
bucket left open, a row policy that was never written, a language model whose
output is treated as an authorization decision. Not dependency CVEs, not
cryptographic review, not compliance, not style.

The bar for adding anything here: **does it help distinguish reality from
appearance?** Breadth is not the goal and never becomes one.

It never reports ✅ SAFE. The strongest verdict available is **NO SHIP-BLOCKING
FINDINGS DETECTED**, because no static pass can certify an application — and the
gap between "found nothing" and "there is nothing" is exactly what this tool
exists to refuse to blur.

Start at `references/security.md`; it routes to the rest.

---

## Honesty about your own coverage

End every report with what you could **not** check: files you did not open, a
backend in another repo, a build you could not run, generated code you skipped.

A score computed over half a codebase, presented as if it covered all of it, is the
same kind of lie this tool exists to catch. Report coverage as a fraction of the
promises you found, not as a feeling.
