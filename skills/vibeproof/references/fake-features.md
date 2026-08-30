# 🎭 Fake Features

The UI presents a working feature. The code behind it produces no real effect.

The test for this category: **if the backend were switched off, would this part of
the screen look any different?** If not, it is fake.

---

## 1. Hardcoded data presented as live

```jsx
// FAKE — a dashboard metric that never changes
const revenue = [4200, 5100, 4800, 6300, 7100];
return <LineChart data={revenue} title="Monthly revenue" />;
```

**How to detect:** array/object literals of realistic-looking business values
(amounts, counts, names, dates) rendered by a component whose label implies live
data — "revenue", "users", "orders", "analytics", "activity", "stats".

**Confirm before flagging:** grep for a fetch/query that would populate it. If a real
data path exists and the literal is only a fallback for the loading state, it is not
fake — mention it as a CLEANUP if the fallback is indistinguishable from real data.

**Severity:** RISK normally. BLOCKER when the number drives a decision (billing,
balance, quota, capacity).

---

## 2. Handlers that do nothing

```jsx
<button onClick={() => {}}>Export CSV</button>
<button onClick={() => console.log('clicked')}>Invite member</button>
<button onClick={handleDelete}>Delete</button>   // handleDelete has an empty body
```

**How to detect:** handler props bound to an empty arrow, a lone `console.log`, or a
function whose body contains no call, assignment, navigation, or state change.

**Check first:** is the control `disabled`? Is the handler on a parent? Is this a
Storybook story? See `false-positives.md`.

**Severity:** RISK. BLOCKER when the label promises a destructive or paid action
("Delete account", "Cancel subscription") — a user may believe it happened.

---

## 3. Mock data reachable in production

```js
const users = process.env.NODE_ENV === 'test' ? MOCK_USERS : await db.users.findMany();
```
Fine. But:
```js
const users = MOCK_USERS;                       // FAKE
const users = await db.users.findMany() ?? MOCK_USERS;   // FAKE ON FAILURE
```

The second is worse than the first: it looks correct, and it silently shows fabricated
data exactly when the database is down.

**How to detect:** identifiers matching `mock`, `dummy`, `sample`, `fake`, `stub`,
`placeholder`, `seed`, `demo`, `test` imported into a non-test module. Then check
whether any production code path reaches them.

**Severity:** BLOCKER when a fallback substitutes fabricated data for real data at
runtime. RISK when it is reachable only via a flag.

---

## 4. Simulated latency

```js
await new Promise(r => setTimeout(r, 1500));   // pretending to load
setStatus('done');
```

An artificial delay with no operation behind it is a fake feature wearing a spinner —
it exists purely to make the absence of work feel like work.

**Severity:** RISK. BLOCKER if it replaces an operation the UI claims happened.

**Not a finding when:** the delay is debounce, throttle, retry backoff, animation
timing, or a rate-limit pause — all of which sit alongside a real operation.

---

## 5. Placeholder content shipped

`lorem ipsum`, `John Doe`, `example@example.com`, `Coming soon`, `TODO`, `FIXME`,
`Replace this`, `Your text here`, `xxx`, `asdf` in rendered output.

**Severity:** CLEANUP normally; RISK if it appears in a paid or legal surface
(pricing, terms, invoice, receipt).

---

## 6. Hardcoded identity and configuration

```js
const userId = 'user_123';
const API = 'http://localhost:3000/api';
const ADMIN = 'admin@test.com';
```

Three distinct problems:
- **Hardcoded user/tenant ID** — the app works for exactly one account. BLOCKER.
- **localhost URL** in shipped code — breaks entirely off the developer's machine. BLOCKER.
- **Hardcoded credential or key** — see below.

**Secrets:** a literal that looks like a live credential (`sk_live_`, `AKIA`,
`ghp_`, a JWT, a private key block, a connection string with a password) is a
BLOCKER. Report the location and the *kind* of secret. **Never reproduce the secret
value in the report** — reports get pasted into issues and chat.

---

## 7. Feature exists in the UI only

A settings toggle, a filter, a sort control, a "dark mode" switch that writes to a
state variable nothing else reads.

**How to detect:** find the state setter, then grep for readers of that state. Zero
readers outside the control itself means the control is decorative.

**Severity:** RISK.

---

## 8. Search and filter that only touch a local array

```js
const results = ALL_ITEMS.filter(i => i.name.includes(q));   // ALL_ITEMS is a literal
```

The box accepts typing and returns results, so it feels real. It searches a fixture.

**Flag when:** the collection being filtered traces back to a literal rather than a
fetch/query. **Not a finding when** the full set is legitimately client-side and
small (a static docs index, a country list).
