# Known limitations

VibeProof exists to tell you when something looks finished and isn't. A tool built
on that claim does not get to be vague about its own gaps.

This document is the honest version: what it misses, what it deliberately refuses
to do, and where it is currently weakest. It is maintained as a first-class file,
not an appendix.

The governing principle:

> **VibeProof prefers an explicit "I could not verify this" over invented certainty.**

A missed bug is unfortunate. A fabricated blocker destroys the tool.

---

## What VibeProof deliberately does not claim

It does **not** claim to find every broken promise. It claims that what it reports
is backed by quoted evidence.

It does **not** claim your app works. It claims a specific chain either resolves or
breaks at a named hop.

It does **not** claim to be a security scanner, a linter, a code reviewer, a test
coverage tool, or a performance analyzer. Those exist and are good.

It does **not** claim that an external effect happened. Finding a Stripe SDK call
proves a call site exists — not that a payment can complete.

It does **not** modify your code. An auditor that also patches loses the standing
to be trusted about what was broken.

---

## Known blind spots

### 1. There is no measured accuracy

There is no precision, recall, or false-positive rate for this tool, because no
benchmark has been run. What exists is two real audits — one of them against this
repository itself.

Any number you see quoted about VibeProof's accuracy today would be made up. None
are published for exactly that reason. An eval fixture set is the highest-priority
next piece of work.

### 2. Product contract discovery is not deterministic

VibeProof first works out what your app *claims* to do, then traces each claim. That
first step is model reasoning, not parsing. Two agents can produce two slightly
different promise lists from the same repository.

The scoring arithmetic is deterministic. **The input set is not.** This is the
weakest link in any reproducibility claim, and it is why the README says the same
*confirmed finding set* scores the same, rather than the same *commit*.

### 3. Absence is asserted more confidently than it is proven

Findings of the form "this route does not exist" or "no handler is wired" are
absence claims, and absence is much harder to establish than presence. A route can
legitimately resolve through a rewrite, a route group, a dynamic segment, a server
action, a proxy, middleware, a monorepo package, or a framework convention that was
not searched.

Today the skill instructs a broad search before declaring absence. It does not yet
require a documented negative-proof procedure with a stated search scope. Until it
does, treat "missing route" findings as the class most likely to be wrong.

### 4. One defect can be counted more than once

A dead `Export` button can plausibly match Ghost UI *and* Fake Feature. The category
references overlap by design — they describe the same product failure from different
angles — but the scoring model does not yet enforce one penalty per root cause.

The practical effect: a small number of real defects can depress the Reality Score
more than they should.

### 5. "Only PROVEN findings can be blockers" mixes two different axes

The current model puts `PROVEN`, `UNPROVEN`, `FAKE` and `BROKEN` on one axis, then
says only a `PROVEN` finding may be a blocker. Those are not the same kind of
statement: `FAKE` describes the *product*, `PROVEN` describes the *evidence*. A
feature can be genuinely fake and the evidence for it can be strong or weak,
independently.

These should be two axes — product status and evidence level — and the blocker gate
should sit on the evidence axis. They are not yet separated.

### 6. Zero findings is not the same as nothing wrong

The report format currently allows zero blockers and zero risks to produce a ship
verdict, even when coverage was thin — for example when the backend was unavailable,
the build never ran, or only a fraction of promises were traced.

"Found nothing" and "there is nothing" are different statements, and the verdict
does not yet distinguish them.

---

## Evidence limitations

Every finding is expected to carry a real `file:line` and a verbatim quote. That
rule is enforced by instruction, not by a parser — it constrains an agent, it does
not make cheating impossible.

Static tracing cannot observe behaviour. When VibeProof says a chain resolves, it
means every hop was found in source, not that the feature was exercised. Runtime
evidence, where a safe build or existing test can be run, is stronger and is
currently under-used.

Evidence is also tied to a code state. Nothing today marks earlier verification
stale after the relevant implementation changes.

---

## Tripwire limitations

`hooks/tripwire.sh` is a two-second smell test that runs after your agent stops. It
is grep-based on purpose: no syntax tree, no dependencies, POSIX shell. It exists to
answer *"is an audit worth running?"* — never to be the audit.

Grep-level matching means it will always both over- and under-report at the margins.
That is accepted. The following are specific defects, found in external review, and
they are real:

**Filenames containing whitespace are skipped.** The changed-file list is passed to
`grep` unquoted, so a path such as `src/a b.js` is split into two nonexistent paths
and silently produces no match. This is a genuine false negative.

**Fetch status checks are counted repository-wide, not per operation.** The check
compares the total number of `fetch` calls against the total number of status checks
across all changed files. An unrelated `if (res.ok)` in a different file therefore
masks a genuinely unchecked `fetch` in another. Correlation needs to be per
operation, or at minimum per file and local context.

**"Strongest signal" is actually the first signal found.** The hook reports one
representative pattern and describes it as the strongest, but it keeps whichever
matched first. In a file containing both a no-op button and a hardcoded credential,
it reports the no-op button. Signals need an explicit severity order.

Two further gaps: the file-type filter misses `.mjs`, `.cjs`, `.mts` and `.cts`; and
only added/copied/modified files are examined, so deleting a route or handler —
which is a very effective way to break wiring — produces no signal at all.

These are scheduled, not disputed.

---

## Framework limitations

`references/false-positives.md` encodes conventions for Next.js, Nuxt, SvelteKit,
Remix, NestJS, FastAPI, Spring and Rails. For a framework outside that list, a
"missing route" or "missing endpoint" finding is materially more likely to be wrong,
because the convention that would resolve it was never searched.

The skill requires this to be stated in the report's coverage section. It cannot
guarantee it.

Monorepos are a related weakness. A frontend route can legitimately terminate in a
sibling workspace package, and cross-package tracing is not yet systematic.

---

## HTTP client semantics

`references/false-success.md` suppresses false-success findings for clients that
reject non-2xx responses by default — `axios`, `ky`, `got`.

The default behaviour is correctly described, but defaults are configurable:
`validateStatus` on axios, `throwHttpErrors` on ky and got, response interceptors,
hooks, and per-request overrides all change it. The current wording also generalises
about generated SDKs more broadly than the evidence supports.

Package name is not behaviour. Until the suppression rule requires inspecting the
client instance and its configuration, this is a source of false negatives.

---

## Intentional tradeoffs

**Precision over recall.** Evidence requirements get stricter as severity rises. The
tool will miss things rather than accuse code it cannot prove is broken. This is a
deliberate asymmetry, not an accident of implementation.

**Read-only, always.** Suggesting the fix and applying it are different jobs. Doing
both compromises the first.

**Location lowers suspicion; it should not be a blanket exemption.** Findings in
`examples/`, `demo/`, `scripts/`, `tools/` and `bin/` are suppressed more readily.
That is usually right and occasionally wrong — `bin/` can be the shipped product.
Reachability, not directory name, is the correct test, and the rules are not yet
written that way.

**No dependencies.** The core skill is markdown an agent reads. This rules out
parsing, AST analysis and static type information, and that ceiling is accepted in
exchange for working identically in Claude Code, Cursor and Codex with nothing to
install.

**No confidence percentages.** "93% confident" reads as science and is not
calibrated. Evidence level is a factual statement about what was checked; a
percentage would not be.

---

## It was run against itself

VibeProof audited its own repository and found three defects. Two mattered:

- `install.sh --with-hook` did not install the hook. It changed the text of two
  `echo` lines and exited successfully. By VibeProof's own taxonomy: Ghost UI — a
  control that reports success and does nothing.
- `tripwire.sh` check 1 passed silently whenever exactly one file changed, which is
  the most common case. `grep -B1` omits the filename prefix when given a single
  file, so the parsing that followed never matched.
- The README advertised six reference files. There were seven.

All three are fixed. Both serious ones were found by *running* the thing and
checking the result against what it claimed — not by reading the code.

That is the same method the tool asks of you, and the reason this file exists.

---

## Reporting a gap

False positives and false negatives are the most valuable thing you can send.

For a **false positive**: the finding, a minimal example, and why the code is
actually correct — including the framework or client involved.

For a **false negative**: the product promise, the hop that actually breaks, and a
minimal reproduction.

Both become test fixtures.
