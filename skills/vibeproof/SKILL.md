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

Classify the promise:

| Verdict | Meaning | Bar for claiming it |
|---|---|---|
| ✅ **PROVEN** | Chain complete end to end | You followed every hop |
| ⚠️ **UNPROVEN** | Chain plausible but you could not verify a hop | Say which hop |
| 🎭 **FAKE** | UI implies a real effect; code produces none | Quote the no-op |
| 💥 **BROKEN** | Chain points at something that does not exist | Quote both sides |

When torn between UNPROVEN and FAKE, choose **UNPROVEN**. Uncertainty is a fact
about your evidence, not about their code — report it as such.

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

**Before writing any finding, check it against `references/false-positives.md`.**
That file is not optional. Most bad audits come from flagging test fixtures,
Storybook stories, seed scripts, and intentional demo modes.

### Step 4 — Verify what you can actually run

If a build/test/typecheck command exists in the project's manifest, run it and
report the real result. A failing build outranks every other finding.

Do not report "build passes" unless you ran it. Say "not run" instead.

### Step 5 — Report

Use `references/report-format.md` exactly. Score is arithmetic, not judgement —
see the formula there. Two people running VibeProof on the same commit must get
the same score.

---

## Severity

Severity comes from **consequence to a user**, never from how the pattern looks.

| Level | Test | Example |
|---|---|---|
| 🔴 **BLOCKER** | Users lose data, lose money, or are lied to | "Payment successful" before the charge resolves |
| 🟠 **RISK** | Feature silently fails or degrades | Error swallowed, user sees nothing |
| 🟡 **CLEANUP** | Ugly but harmless | `console.log` in a handler |

Hard constraint: **only a PROVEN finding may be a BLOCKER.** If you could not
verify it, it is at most a RISK. This single rule is what keeps
"DO NOT SHIP" meaningful.

---

## Modes

| Command | Scope |
|---|---|
| `/vibeproof` | Whole repository |
| `/vibeproof diff` | Only what changed vs. the default branch (`git diff`) |
| `/vibeproof feature <name>` | One flow, traced end to end |

`diff` mode is the one to use in a PR: it answers "did this change ship a lie?"
rather than re-litigating the whole codebase.

In `feature` mode, output the per-step table for that flow (see report format) and
skip the repository-wide score — a single feature does not have one.

---

## Scope

**In scope:** does the product do what its interface says it does.

**Out of scope:** code style, architecture opinions, test coverage percentages,
performance tuning, dependency version bumps. Other tools do those well. Saying
"this component is too long" in a VibeProof report dilutes the findings that
actually block a release.

Security appears here **only** where it is a broken promise — auth that is checked
in the browser and not on the server, an admin route with no guard. Full security
review is a different tool.

---

## Honesty about your own coverage

End every report with what you could **not** check: files you did not open, a
backend in another repo, a build you could not run, generated code you skipped.

A score computed over half a codebase, presented as if it covered all of it, is the
same kind of lie this tool exists to catch. Report coverage as a fraction of the
promises you found, not as a feeling.
