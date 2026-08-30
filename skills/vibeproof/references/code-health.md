# Code Health

The category most likely to ruin the report.

Maintainability findings are infinite. Any codebase yields a hundred of them, they
are cheap to generate, they all sound reasonable, and every one added pushes the
finding that stops a release further down the page. A reader who scrolls past
thirty style notes stops reading before the blocker.

So this section exists, it is thorough, and it is **rationed**.

---

## The bar

Report a code-health finding only when it meets one of these. Not "it would be
nicer if".

**It hides a defect.** Structure that makes a bug invisible or a fix dangerous.

**It defeats the type system or the tests.** A safety net that is switched off is
worse than no net, because everyone believes it is on.

**It is a landmine.** Correct today, and the next reasonable change makes it wrong.

Everything else — naming, file length, formatting, function shape, folder layout,
your opinion about hooks — is counted, not listed:

```
CODE HEALTH   4 findings · 61 style observations not listed
```

Four names a reader will actually read. Sixty-one is a wall.

---

## Safety nets switched off — `VP-CH-001`

```jsonc
// tsconfig.json
{ "strict": false, "noImplicitAny": false }
```
```js
// @ts-nocheck
// eslint-disable
```
```python
# type: ignore
```

The project declares it is typechecked. It is not. This is the highest-value
finding in the whole category, because everything downstream — including any claim
this audit makes about types — rests on it.

Worse, and specifically: `strict: true` in `tsconfig.json` while the build ignores
type errors:

```js
// next.config.js
typescript: { ignoreBuildErrors: true },
eslint:     { ignoreDuringBuilds: true },
```

That is a build that is green by construction. 🔴 when combined with a failing
typecheck, because the failure is real and invisible.

Same class: a test suite where the failing test is `.skip`ped rather than fixed, a
CI step with `continue-on-error: true`, and `--passWithNoTests` in a project that
claims coverage.

## `any` at a boundary — `VP-CH-002`

```ts
export async function POST(req: Request) {
  const body: any = await req.json();
  await db.user.update({ where: { id }, data: body });
}
```

Interior `any` is untidy. `any` on **untrusted input** is a validation hole wearing
a type annotation — and here it is also `VP-IN-007`, mass assignment. Report the
one root cause with the other as a tag.

The general rule: type assertions (`as User`, `!`, `cast()`) on data that came from
the network assert something nobody checked.

## Duplicated logic that has already diverged — `VP-CH-003`

Duplication alone is not a finding. **Diverged** duplication is:

```
src/api/checkout.ts:44      if (user.credits >= price)
src/api/subscribe.ts:71     if (user.credits > price)
```

Two copies of one rule that disagree. One of them is a bug, and fixing it in one
place leaves the other. Quote both lines; the difference is the finding.

Three copies that agree: worth one line in the count, not a finding.

## Dead code that looks live — `VP-CH-004`

An exported function nothing imports, a route file nothing links to, a feature flag
permanently false, a component never rendered.

Harmless until someone reads it to understand behaviour, or fixes a bug in the copy
that does not run. Reachability matters more than tidiness: dead code inside an
**auth or payment** path is worth naming, because that is where someone will look
first and be misled.

## Configuration that only works here — `VP-CH-005`

```js
const API = "http://localhost:3000";
const SUPPORT = "dev@localhost";
if (process.env.NODE_ENV !== "production") { /* the only branch ever taken */ }
```

Absolute paths from one machine, a hardcoded developer email, a region or account
ID inlined. It works for the person who wrote it. Overlaps `VP-HD-001` when it also
makes the feature fake.

## Error messages that end the trail — `VP-CH-006`

```js
throw new Error("Something went wrong");
catch (e) { throw new Error("Failed"); }              // original discarded
```

The second one is worse than silence: the stack that would have explained the
failure is gone, replaced by a word. When production breaks, this is the difference
between five minutes and an afternoon.

## Migrations that cannot be re-run — `VP-CH-007`

A migration that fails on second run, has no down path, or drops a column in the
same deploy that stops writing to it. This is where a bad afternoon becomes lost
data.

---

## What is never reported

- Formatting, quote style, semicolons, import order — a formatter's job
- File or function length as a number
- Preferences about state management, folder structure or component shape
- Comment density
- Test coverage percentage as a target

Some of those are worth having opinions about. None of them belong in a report
whose job is to tell someone whether to ship.
