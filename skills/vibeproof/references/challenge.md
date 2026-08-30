# The Challenge Pass

A BLOCKER tells someone not to ship. That is the strongest thing this tool can say,
so it is the claim that has to survive the most scrutiny.

> **Every proposed BLOCKER must be attacked before it is published.**
>
> You wrote the finding. Now try to destroy it. If it survives, it ships with the
> report. If it does not, it is downgraded or deleted.

The point is not ceremony. The point is that the first pass looks for evidence
*that the finding is true*, and that is exactly the search most likely to miss the
thing that makes it false.

---

## How to run it

Take the finding as an accusation and look for the innocent explanation. Concretely,
for each finding type:

### Missing route or endpoint

Run the full [negative proof](negative-proof.md) search. Rewrites, route groups,
dynamic segments, server actions, proxies, middleware, workspace packages. A single
missing filename is not proof of a missing route.

### False success

- Is the call actually un-awaited, or does the surrounding function await it?
- Does the HTTP client reject non-2xx by default, and is that default still in force?
  Check the instance config, `validateStatus` / `throwHttpErrors`, interceptors and
  hooks, and any per-request override.
- Is there an error boundary, a global handler, or an interceptor that turns a
  rejection into a visible failure elsewhere?
- Is this optimistic UI **with a real rollback path**? Find the rollback. If it
  exists, this is not false success.
- Does the success message actually refer to this operation, or to a different one
  that did complete?

### Dead control / Ghost UI

- Is the handler attached higher up — event delegation, a parent form's `onSubmit`,
  a framework binding rather than an inline prop?
- Is the component driven by config, a registry, or a generated map?
- Is it disabled deliberately behind a flag, with the UI correctly reflecting that?

### Fake persistence

- Does persistence happen through a server action, RPC, or SDK rather than a `fetch`
  you were looking for?
- Is the storage layer intentionally client-side, and does the UI promise match that?
- Is this eventually consistent — queued, scheduled, processed later — with UI
  wording that correctly says so?

### Hardcoded data

- Is this a genuine fixed catalogue, a legal constant, an enum, a seed for a demo
  route that is not shipped?
- Is it reachable from the production build at all?

---

## The gate

A BLOCKER is permitted only when **all** of these hold:

| Condition | Meaning |
|---|---|
| Evidence is `STATIC VERIFIED` or `RUNTIME VERIFIED` | Every necessary hop was traced, or the failure was observed by running something |
| `production_reachable` | The code path ships; it is not test, fixture, story, or dead |
| `user_visible` | A real user encounters the promise |
| Consequence is critical | Data loss, money, auth, or being told something happened that did not |
| Challenge passed | This document was actually applied |

Fail any one, and it is at most a RISK.

A `PARTIAL` or `SUSPECTED` finding can never be a BLOCKER, regardless of how bad it
would be if true. Severity is about consequence; the evidence gate is about whether
you are entitled to make the claim at all.

---

## What appears in the report

One line on the finding:

```
Challenge: survived — searched rewrites, route groups, server actions and both
           workspace packages
```

Or, if it did not:

```
VP-003 withdrawn — next.config.js rewrites /checkout to an external billing host
```

Report withdrawn findings. A tool that quietly drops its own mistakes teaches you
nothing about how much to trust the ones it kept.

Do not print your reasoning. Print what you searched and what you found.

---

## On being wrong

If the challenge disproves a finding, that is the system working, not a failure.
The alternative — publishing it and being contradicted by the developer who knows
their own rewrite config — costs far more. One fabricated blocker is remembered
longer than ten correct ones.
