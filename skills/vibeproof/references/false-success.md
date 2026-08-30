# 🤥 False Success

**The signature VibeProof category.** Everything else in this tool finds things that
visibly do nothing. This finds things that visibly do the *wrong* thing: the app
tells the user it worked when it did not.

This is the most damaging failure in an AI-generated app, because the user acts on
the confirmation. They close the tab. They tell a customer it is done. They stop
worrying about the thing that silently failed.

---

## 1. Success announced before the work resolves

The promise is made, then abandoned.

```js
// FAKE — the toast fires immediately; the request may still fail
saveUser(form);
toast.success("Profile saved");
```

```js
// PROVEN
await saveUser(form);
toast.success("Profile saved");
```

**How to detect:** find calls to notification/toast/alert/`setStatus` with success
wording. Walk backwards to the operation they refer to. Flag when the operation is
async (returns a promise, is declared `async`, or is a known client like `fetch`,
`axios`, `supabase`, `prisma`) and is **not** awaited, `.then()`-chained, or inside
the resolved branch.

**Severity:** BLOCKER when the operation writes data or money. RISK otherwise.

**Not a finding when:** the call is deliberately fire-and-forget *and* the UI does
not claim completion — e.g. analytics, logging, prefetch.

---

## 2. Catch that returns success

The error is caught and converted into a lie.

```js
// FAKE
try {
  await chargeCard(amount);
} catch (e) {
  return { success: true };          // ← the charge failed
}
```

```python
# FAKE
try:
    send_email(user)
except Exception:
    pass
return {"status": "sent"}
```

**How to detect:** in every `catch`/`except` block, look at what is returned or set.
Flag when the handler produces a success value, a 2xx response, or a success message
while the failure is discarded.

**Severity:** BLOCKER — always. The user is told a false fact about their data.

---

## 3. Errors swallowed with no user-visible consequence

```js
// RISK — the user waits forever, nothing tells them it failed
try {
  await loadOrders();
} catch (e) {
  console.error(e);
}
```

The distinction from #2: nothing claims success, but nothing reports failure either.
The interface just sits there.

**Flag when:** a `catch` in a user-triggered path only logs (or is empty) and leaves
no error state, no message, no retry affordance.

**Severity:** RISK. BLOCKER if it hides a failed write.

---

## 4. HTTP status ignored

`fetch` does **not** throw on 4xx/5xx. This is the single most common false-success
bug in AI-written JavaScript.

```js
// FAKE — a 500 lands here as "success"
const res = await fetch('/api/save', { method: 'POST', body });
toast.success("Saved");
```

```js
// PROVEN
const res = await fetch('/api/save', { method: 'POST', body });
if (!res.ok) throw new Error(await res.text());
toast.success("Saved");
```

**How to detect:** every `fetch(` whose result is used without checking `res.ok`,
`res.status`, or an equivalent guard, in a path that then reports success.

**Severity:** BLOCKER on a write path, RISK on a read path.

**Not a finding when:** the project uses a client that throws on non-2xx by default
(axios without `validateStatus`, `ky`, `got`, most generated SDKs). Confirm which
client is in use before flagging.

---

## 5. Result computed but never checked

```js
// RISK
const { error } = await supabase.from('posts').insert(row);
router.push('/posts');            // error is never read
```

Common with clients that return errors in the value rather than throwing: Supabase,
Go's `err`, Rust's `Result`, many SDKs.

**How to detect:** a destructured `error`/`err` that no subsequent statement reads.

---

## 6. Validation only in the browser

```js
// RISK — trivially bypassed with curl
if (!isValidEmail(email)) return;
await fetch('/api/subscribe', { method: 'POST', body: JSON.stringify({ email }) });
```

Client-side validation is a UX affordance. When the server does not repeat the check,
the guarantee the form implies does not exist.

**Flag when:** a constraint is enforced in the component and the corresponding server
handler has no equivalent check.

**Severity:** RISK. BLOCKER when the constraint is authorization or payment amount.

---

## 7. Partial write reported as complete

```js
// RISK — if the second call fails, the user is told everything saved
await saveProfile(p);
await saveAvatar(a);
toast.success("All changes saved");
```

Two writes, no transaction, one confirmation. Flag when a success message covers
multiple independent writes with no rollback or per-step reporting.

---

## Writing these findings

Quote **both** lines: the operation and the claim. The gap between them is the whole
finding, and a reader must see it without opening the file.

```
🔴 VP-001  False success on account deletion
src/components/Profile.tsx:118

    deleteAccount(user.id);
    toast.success("Account deleted successfully");

deleteAccount() is async (declared at src/api/account.ts:40) and is not awaited.
The toast fires regardless of the result; a rejected promise surfaces only as an
unhandled rejection. The user is told their account is gone when it may not be.
```
