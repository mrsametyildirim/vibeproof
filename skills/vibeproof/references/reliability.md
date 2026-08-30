# Reliability and Performance

Everything here is judged by one question: **will a user notice?**

That keeps this section from becoming a style guide with extra steps. An unbounded
query is not a finding because it is inelegant — it is a finding because the page
stops loading once the table reaches fifty thousand rows, and the app was tested
with twelve.

That gap is why this belongs in the same tool. AI-assembled code is written against
the demo dataset, and the failure arrives later, in production, at scale, on the
unhappy path — which is exactly the shape of every other thing VibeProof looks for.

---

## Unbounded work — `VP-RL-001`

```js
const users = await db.user.findMany();                       // every row, forever
const rows = await db.query("SELECT * FROM events");
```

Correct on the twelve rows it was built against. At scale it exhausts memory,
times out, and takes the process with it.

Look for: a list endpoint with no `take`/`limit`, a UI list with no pagination or
virtualisation, `SELECT *` on a wide table feeding a client, an export that
materialises everything into an array before writing, a file read fully into memory
rather than streamed.

🟠 normally. 🔴 when it is on a path a user hits routinely and the table grows
without bound — events, logs, messages.

## N+1 queries — `VP-RL-002`

```js
const posts = await db.post.findMany();
for (const p of posts) {
  p.author = await db.user.findUnique({ where: { id: p.authorId } });
}
```

One query becomes N+1. Fine at ten, fatal at ten thousand. In ORMs it hides behind
lazy relations that look like property access. The fix is `include`, `join`,
`select_related`, or a batched loader.

## Missing timeouts — `VP-RL-003`

```js
const r = await fetch(url);                    // no timeout: waits forever
```

Node's `fetch` has no default timeout. Neither does `axios`. A hung upstream turns
into a hung request, then an exhausted connection pool, then an outage caused by
someone else's slow server.

Every outbound call needs a deadline: `AbortSignal.timeout()`, an axios `timeout`,
`httpx.Timeout`, a context deadline in Go. Retries need a bound and backoff —
unbounded retry against a struggling service is how a slowdown becomes an outage.

## Errors that go nowhere — `VP-RL-004`

```js
try { await save(); } catch (e) {}                       // swallowed
promise.catch(() => {});                                 // swallowed
```

Distinct from `VP-FS-002` (`catch` reporting *success*): here nothing is reported
at all. The user sees a button that did nothing, and no log records why.

Related and worth checking as a set: a React tree with no error boundary, so one
component's throw blanks the page; an `unhandledRejection` with no handler, which
terminates a Node process; and a background job whose failure is invisible.

## Race conditions — `VP-RL-005`

```js
const balance = await getBalance(userId);
if (balance >= amount) {
  await setBalance(userId, balance - amount);            // two tabs, both pass
}
```

Read-check-write without a transaction or an atomic update. The window is small,
which is why it survives testing and shows up as an accounting discrepancy later.

Same family: double-submit with no idempotency key on payment; `upsert` emulated as
`find` then `create`; a webhook handler with no replay protection, when providers
guarantee at-least-once delivery.

🔴 when money, credits or entitlements are involved.

## No rate limiting — `VP-RL-006`

Not every endpoint needs it. These do: login and password reset (credential
stuffing, and enumeration through timing or distinct error messages), anything that
sends email or SMS (someone else's bill), signup (bot floods), and anything calling
a paid model API — a public endpoint proxying an LLM with no limit is a
metered-cost incident waiting to happen.

## Blocking the request path — `VP-RL-007`

Image processing, PDF generation, sending a batch of email, calling a slow third
party — done inline, so the user waits and the request times out. The work belongs
on a queue, with the UI promising the stage that is actually guaranteed. Which is
`VP-FS-003`: if it is queued, the copy says queued.

Client side, the equivalent: a synchronous loop over a large array on the main
thread, or a bundle large enough to delay first paint by seconds on a phone.

## Cache and invalidation — `VP-RL-008`

A cache with no invalidation on write shows stale data after a successful save —
which reads to the user exactly like `VP-FP-001`, fake persistence: they saved, it
looked fine, they refreshed, the old value is back. The difference is only visible
in the code, so check which one it actually is before writing the finding.

Also: caching a **per-user** response in a shared or CDN cache. That is not a
performance bug, it is one user seeing another user's data.

---

## The bar

Report something here only if you can name the user-visible consequence in one
sentence:

- ✅ "The dashboard stops loading once a workspace passes a few thousand events."
- ✅ "Two clicks on Buy charge the card twice."
- ❌ "This function could be more efficient."
- ❌ "Consider extracting this into a helper."

If the sentence needs the word *could* twice, it is not a finding. Fold it into the
Health count or leave it out.
