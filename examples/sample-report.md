# Sample Report

A full `/vibeproof` run against a typical AI-generated Next.js SaaS dashboard.

---

```
╭──────────────────────────────────────╮
│              VIBEPROOF               │
│                                      │
│         REALITY SCORE  64/100        │
│                🟠 VIBEY              │
╰──────────────────────────────────────╯

18 product promises traced

  ✅  11  PROVEN
  ⚠️   2  UNPROVEN
  🎭   3  FAKE
  💥   2  BROKEN

  🔴  2 blockers    🟠  5 risks    🟡  9 cleanups
```

## Product Contract

```
Detected: SaaS dashboard (Next.js 14 app router, Prisma, Supabase auth)

USER FLOWS
  01  Sign up                    05  Search projects
  02  Log in                     06  Edit profile
  03  Create project             07  Upgrade plan
  04  Delete project             08  Log out

VISIBLE CLAIMS
  "Your changes are saved"   ·   "Export CSV"
  "Upgrade to Pro"           ·   "Delete Account"
```

---

## Biggest Lie

```
src/components/Profile.tsx:118

    deleteAccount(user.id);
    toast.success("Account deleted successfully");

The UI reports success unconditionally. deleteAccount() is async
(src/api/account.ts:40) and is never awaited, so the message fires whether the
request succeeds, fails, or never resolves. A user who sees this believes their
account is gone.
```

---

## 🔴 Blockers

**VP-001 · False success on account deletion**
`src/components/Profile.tsx:118`

```jsx
deleteAccount(user.id);
toast.success("Account deleted successfully");
```

`deleteAccount` returns a promise that is never awaited. A rejection surfaces only
as an unhandled rejection in the console. The user is told their account is deleted
when the request may have failed.
*Fix: await the call and show the success message only on the resolved path.*

---

**VP-002 · Upgrade button links to a route that does not exist**
`src/app/pricing/page.tsx:144` → `/checkout`

```jsx
<Link href="/checkout" className="btn-primary">Upgrade to Pro</Link>
```

No `app/checkout/page.tsx`, no route handler, and no rewrite in `next.config.js`
resolves `/checkout`. The primary conversion path is a 404.
*Fix: create the route, or point the link at the real checkout target.*

---

## 🟠 Risks

**VP-003 · Profile changes are not persisted**
`src/app/settings/page.tsx:83`

```jsx
function handleSave() {
  setProfile(form);
  toast.success("Changes saved");
}
```

Writes only to component state — no fetch, server action, or storage call in this
file or its imported helpers. After a refresh the previous values return, while the
user has been told the change was saved.
*Fix: call the update mutation and await it before showing the message.*

---

**VP-004 · Revenue chart renders hardcoded data**
`src/components/Dashboard.tsx:41`

```jsx
const revenue = [4200, 5100, 4800, 6300, 7100];
return <LineChart data={revenue} title="Monthly revenue" />;
```

No query populates this series. The chart shows the same five values for every user
and every month.
*Fix: fetch from the revenue endpoint, or label the component as a placeholder.*

---

**VP-005 · HTTP status ignored on project creation**
`src/features/projects/create.ts:29`

```ts
const res = await fetch('/api/projects', { method: 'POST', body });
router.push(`/projects/${(await res.json()).id}`);
```

`fetch` does not throw on 4xx/5xx. A 500 reaches the same path as a success and the
redirect runs with an undefined id.
*Fix: check `res.ok` before reading the body.*

---

**VP-006 · Email validation exists only in the browser**
`src/components/SignupForm.tsx:52` · server: `src/app/api/signup/route.ts:14`

The component rejects malformed addresses; the route handler inserts whatever it
receives. The constraint the form implies is not enforced.
*Fix: validate in the route handler as well.*

---

**VP-007 · Three controls have no handler**
`src/components/Toolbar.tsx:44` · `:51` · `src/app/login/page.tsx:88`

```jsx
<button className="btn-ghost">Export CSV</button>
```

"Export CSV", "Invite member" and "Forgot password?" render unconditionally, are not
disabled, and have no `onClick`, form association, or ancestor handler.
*Fix: wire them, or remove them until they exist.*

---

## 🟡 Cleanups

```
VP-008   console.log left in submit handler        src/features/auth/login.ts:31
VP-009   lorem ipsum in empty state                src/components/EmptyState.tsx:12
VP-010   TODO in a reachable branch                src/lib/billing.ts:77
VP-011   Orphan component, never imported          src/components/OldSidebar.tsx
VP-012   Unused export                             src/lib/format.ts:44
… 4 more
```

---

## Ship Verdict

```
❌ DO NOT SHIP

2 blockers. Your app looks more complete than it actually is.

The account deletion flow tells users their data is gone without confirming it,
and the upgrade path leads to a route that does not exist.
```

---

## Coverage

```
Files read           128 / 214
Promises traced       18 / 18
Build                 ✅ ran, passed   (npm run build)
Tests                 ⏭️ not run — no test script in package.json

Not checked:
  • src/legacy/ — 34 files, no importers found
  • External URLs — not verified by design
  • Stripe webhook signature — requires runtime secrets
```

---

## Notes on what was *not* reported

A few things matched a pattern but were correctly excluded:

- `mocks/handlers.ts` — MSW fixtures, test-only directory
- `Chart.stories.tsx` — hardcoded props are the point of a Storybook story
- `onClick={() => {}}` in `Tooltip.tsx:22` — the element is `disabled`
- `/assets`, `/static` — static mounts, not application routes
- `catch { /* Safari private mode */ }` — documented intentional ignore

Excluding these is not leniency. A report whose first checked finding turns out to
be a test fixture does not get a second reading.
