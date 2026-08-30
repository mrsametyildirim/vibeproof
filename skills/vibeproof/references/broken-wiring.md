# 🔌 Broken Wiring

One end of a connection exists. The other does not.

These are the most objectively provable findings in VibeProof: you can point at both
sides and show that one is missing. Because they are provable, they are also the ones
most damaged by getting a framework convention wrong — **read the framework section
of `false-positives.md` before reporting any of these.**

---

## 1. Link to a route that does not exist

```jsx
<Link href="/checkout">Upgrade</Link>
```
…and there is no `/checkout` page.

**How to detect:** collect every internal target — `href`, `to`, `router.push`,
`redirect`, `navigate`, `<form action>`. Resolve each against the project's routing
convention:

- File-system routing → look for the file, including route groups `(group)/`,
  dynamic `[id]`, catch-all `[...slug]`, and `page`/`index` naming
- Config routing (React Router, Vue Router) → look in the route table
- Server frameworks → look for the decorator/registration

**Severity:** BLOCKER when reachable from the main navigation or a paid flow.
RISK when it is a deep link or an edge case.

**External URLs are not in scope** — you cannot verify them without a network call,
and a 404 today may be a redirect tomorrow.

---

## 2. Client calls an endpoint the server does not serve

```js
await fetch('/api/projects/archive', { method: 'POST' });
```
…and no server handler answers `POST /api/projects/archive`.

**How to detect:** collect every request path from the client (string literals and
template literals). Collect every route the server registers. Compare, normalizing
path parameters (`/api/users/[id]` ≡ `/api/users/:id` ≡ `/api/users/{id}`).

**Watch for:** method mismatch — the path exists but only for `GET` while the client
sends `POST`. That is the same finding and just as broken.

**Before flagging, rule out:** a proxy/rewrite (`next.config.js` rewrites, `vite`
proxy, nginx config), a monorepo package holding the backend, an API gateway, or a
fully-qualified URL pointing at a different service.

**Severity:** BLOCKER.

---

## 3. Form with no submission path

```jsx
<form>                              {/* no onSubmit, no action */}
  <input name="email" />
  <button type="submit">Subscribe</button>
</form>
```

The button submits, the page reloads, nothing is sent anywhere.

**How to detect:** `<form>` elements with neither `onSubmit`/`@submit` nor `action`,
or a submit handler that never calls anything.

**Severity:** RISK, BLOCKER if it is the primary conversion path (signup, checkout,
contact).

---

## 4. Handler referenced but not defined

```jsx
<button onClick={handleExport}>Export</button>
```
…with no `handleExport` in scope.

In TypeScript this is usually a compile error, so it mostly appears in plain JS,
templates (Vue/Svelte/Blade/ERB), or after a rename. Confirm it is not imported from
a barrel file before flagging.

**Severity:** BLOCKER — it throws at click time.

---

## 5. Route exists, does nothing

```js
app.post('/api/subscribe', (req, res) => {
  res.json({ ok: true });          // nothing was subscribed
});
```

The endpoint responds correctly and performs no work. This is the server-side twin of
a no-op handler, and it is invisible from the client — the request succeeds.

**How to detect:** route handlers whose body contains no persistence call, no external
call, no queue push — only a response.

**Severity:** BLOCKER when the client reports success to the user based on it.

---

## 6. Import of something that is not installed

```js
import { Chart } from 'react-chartjs-2';
```
…absent from `package.json`.

**How to detect:** compare third-party import specifiers against the dependency
manifest. Exclude: relative paths, path aliases (check `tsconfig.json` `paths`,
`jsconfig`, bundler aliases), Node builtins (and `node:` prefix), workspace packages,
peer deps provided by a framework, and type-only imports resolved from `@types/*`.

**Severity:** BLOCKER — the build fails or the module throws at runtime.

---

## 7. Environment variable read but never provided

```js
const key = process.env.STRIPE_SECRET_KEY;      // used
```
…and it appears in no `.env.example`, no deployment config, no documentation.

Also flag the **mismatch** case, which is more common and harder to see: the frontend
reads `NEXT_PUBLIC_API_URL` while the example file defines `API_URL`.

**Severity:** RISK. BLOCKER when the value is required at boot with no fallback.

**Never print a real secret value** found in a committed `.env`. Report that the file
is committed and which keys it contains — the names, not the values.

---

## 8. Database call against a missing table or column

Where a schema is available (Prisma, Drizzle, SQLAlchemy models, migrations), compare
queried names against defined ones.

**Severity:** BLOCKER.

**Only report this when a schema is genuinely present and readable.** With a
schemaless client and no migrations, you cannot know — say so in Coverage.
