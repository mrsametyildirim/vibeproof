# 💾 Fake Persistence

The change appears to work. The user reloads. It is gone.

This is the highest-signal category in a vibe-coded app, because during development
nobody refreshes — you click through, it works, you move on. The bug only appears
to the first real user.

**The test question for every mutation:**

> If the user refreshed the page right now, would their change still be there?

---

## 1. State-only mutation

```jsx
// FAKE PERSISTENCE
function saveProfile() {
  setProfile(form);
  toast.success("Profile updated");
}
```

Nothing left the browser. The toast is a lie and the data is gone on reload.

**How to detect:** find handlers named/labelled as save, update, create, delete,
submit, apply, confirm. Inside each, look for an escape from local state:

- a network call (`fetch`, `axios`, `ky`, generated SDK)
- an ORM/db client (`prisma`, `drizzle`, `supabase`, `mongoose`, `knex`)
- a server action (`"use server"`, tRPC mutation, form `action`)
- explicit local durability (`localStorage`, `IndexedDB`, `AsyncStorage`)

If the only writes are `setX(...)` / `store.x = ...` / `this.x = ...`, it is fake
persistence.

**Severity:** BLOCKER when the UI claims the change was saved. RISK when it makes no
such claim (a draft, a preview, an unsaved-changes state).

---

## 2. Write with no read-back

The mutation persists, but the page never reloads the data — so the UI shows stale
values until a manual refresh, or shows the optimistic value forever.

```js
await updateSettings(next);
// no refetch, no cache invalidation, no router refresh
```

**How to detect:** a successful mutation with no subsequent `refetch`,
`invalidateQueries`, `mutate`, `revalidatePath`, `router.refresh`, or state update
from the response.

**Severity:** RISK.

---

## 3. localStorage treated as a database

```js
localStorage.setItem('orders', JSON.stringify(orders));
```

Survives refresh — so it is not #1 — but it is per-browser, per-device, clearable,
and invisible to any server. Whether that is correct depends entirely on the promise.

**Flag when:** the feature implies cross-device or account-bound data — anything
under a user account, anything in a "synced" or "cloud" surface, anything another
user is supposed to see.

**Not a finding when:** it is genuinely local by design — theme, sidebar collapsed
state, dismissed banners, draft autosave.

**Severity:** RISK.

---

## 4. In-memory server storage

```js
const sessions = new Map();          // module scope
```

Vanishes on restart, and is not shared across instances — so it breaks the moment the
app is deployed with more than one replica, which is the default on most platforms.

**Flag when:** module-scope mutable collections hold user data, sessions, carts,
rate-limit counters, or job state.

**Severity:** RISK. BLOCKER for auth sessions or anything financial.

**Not a finding when:** it is an explicit cache with a real store behind it, or a
short-lived request-scoped value.

---

## 5. Delete that only removes from the list

```js
function handleDelete(id) {
  setItems(items.filter(i => i.id !== id));    // gone from view only
}
```

The row disappears. The record does not. The user believes it is deleted.

**Severity:** BLOCKER — deletion is a promise users act on, including for privacy and
legal reasons.

---

## 6. Upload that never uploads

```js
const onFile = (e) => setPreview(URL.createObjectURL(e.target.files[0]));
```

A preview renders, so it looks like it worked. The bytes never left the page.

**Flag when:** a file input produces only a local object URL or data URL with no
upload request and the UI presents it as attached/saved.

**Severity:** BLOCKER when the UI claims the file was uploaded.

---

## Writing these findings

Name the refresh consequence explicitly — it is what makes the finding land:

```
🔴 VP-003  Profile changes are not persisted
src/app/settings/page.tsx:83

    function handleSave() {
      setProfile(form);
      toast.success("Changes saved");
    }

handleSave writes only to component state. No network call, server action, or
storage write appears in this file or in the imported helpers.
After a page refresh the previous values return, while the user has been told
their changes were saved.
```
