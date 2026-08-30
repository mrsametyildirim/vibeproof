# False Positives — read this before reporting anything

A VibeProof report gets read once. If the first finding a developer checks turns out
to be a test fixture, they close the terminal and never run it again.

**Every finding must survive this file.** Work through it before writing the report.

---

## Location beats pattern

The same line of code is a blocker in one file and completely correct in another.
Where a pattern lives decides whether it is a finding.

**Not a finding when it lives in:**

| Location | Why |
|---|---|
| `**/*.test.*`, `**/*.spec.*`, `__tests__/`, `tests/`, `e2e/`, `cypress/` | Mocks are the point of a test |
| `**/*.stories.*`, `.storybook/` | Storybook renders components with fake props by design |
| `mocks/`, `__mocks__/`, `fixtures/`, `factories/`, `seeds/`, `seeders/` | Named for what they are |
| `examples/`, `demo/`, `playground/`, `sandbox/`, `templates/` | Sample code, not the product |
| `docs/`, `*.md` | Documentation shows illustrative code |
| `scripts/`, `tools/`, `bin/` | Developer utilities are not user-facing |
| `migrations/` | Destructive SQL is the job of a migration |
| `dist/`, `build/`, `.next/`, `out/`, `vendor/`, `node_modules/` | Generated or third-party |
| `*.generated.*`, `*.gen.*`, files with a codegen header | Not hand-written |

**Rule:** if a path segment matches one of these, the finding needs a specific
reason to survive. Say that reason out loud in the finding.

---

## Patterns that look fake but are correct

### `onClick={() => {}}` on an already-handled element
A no-op handler can be deliberate: stopping propagation, satisfying a required prop,
or a placeholder on a `disabled` control. **Check for `disabled`, `aria-disabled`, or
a parent handler before flagging.**

### Hardcoded data behind a feature flag or env check
```js
const data = process.env.NEXT_PUBLIC_DEMO === '1' ? DEMO_ROWS : await fetchRows();
```
This is an intentional demo mode, not a fake feature — **unless** the flag defaults
to on in production config. Then the finding is about the default, and you must
quote the config line that sets it.

### `href="#"` on a control that is not a link
A `#` href on an element with a real `onClick` is a (dated) accessibility pattern,
not a dead link. Flag it only when there is no handler at all.

### `catch {}` that is genuinely intentional
```js
try { localStorage.setItem(k, v); } catch { /* Safari private mode */ }
```
An empty catch with a comment explaining the ignored case is a decision, not a
swallow. Swallowing is when the **user is told it worked** anyway.

### Optimistic UI
```js
setItems(next);                    // optimistic
await save(next).catch(() => setItems(prev));   // rollback on failure
```
Updating UI before the server confirms is a real pattern — **when there is a
rollback path**. Flag it only when failure leaves the wrong state on screen.

### `TODO` in a comment
A TODO is a note. It is a CLEANUP at most. It becomes a RISK only when it sits
inside a code path a user reaches and marks something unimplemented that the UI
already offers.

### Mock/stub packages in `devDependencies`
`msw`, `faker`, `nock` under devDependencies are normal. They are a finding only if
imported from a file that ships to production.

---

## Framework conventions that are not missing wiring

Before reporting "missing route" or "missing handler", confirm you understand how
this project resolves things:

- **File-system routing** (Next.js, Nuxt, SvelteKit, Remix, Astro): a route exists if
  the file exists. `app/checkout/page.tsx` *is* `/checkout`. Check for the file
  before declaring the route missing. Also check route groups `(marketing)/`,
  dynamic segments `[id]`, and catch-alls `[...slug]`.
- **Decorator/annotation routing** (NestJS, FastAPI, Spring, Rails): the route is
  registered by a decorator, not a router file.
- **Convention-based handlers** (Rails controllers, Django views, Laravel resource
  routes): a method name can be the whole wiring.
- **Server actions / RPC** (Next.js `"use server"`, tRPC, Server Components): there
  may be no HTTP endpoint at all. The absence of a `fetch` call is not proof of a
  missing backend.
- **Re-exports and barrel files**: `export * from './x'` means the symbol exists even
  though you did not see it declared where you looked.
- **Monorepos**: the backend may be in another workspace package. Look before
  concluding it is absent.

**If the project uses a framework whose conventions you are not sure about, say so
in the Coverage section rather than reporting a missing hop.**

---

## Things that are simply out of scope

Do not report these, even when true:

- Code style, formatting, naming, file length
- Architectural preferences ("this should be a service")
- Missing tests or low coverage
- Dependency versions, unless an imported package is genuinely absent from the manifest
- Performance, bundle size, accessibility audits
- `console.log` outside a user-facing path (it is a CLEANUP at most, never a RISK)

Every out-of-scope item you include makes the in-scope ones easier to ignore.

---

## The final gate

Before a finding goes in the report, all five must be true:

1. I opened the file and read the line.
2. I can quote the source verbatim.
3. I can name the exact broken hop in the chain.
4. It is not excluded by anything above.
5. A developer reading it would say "yes, that's real" — not "well, actually…".

If you are unsure about #5, downgrade it to UNPROVEN and say what you would need
to confirm it. That is an honest report. A confident wrong one is not.
