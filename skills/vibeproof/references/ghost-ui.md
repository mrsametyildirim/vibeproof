# 💀 Ghost UI

Controls the user can see and click that connect to nothing.

Ghost UI is not the same as a fake feature. A fake feature *does something wrong*.
Ghost UI *does nothing at all* — and because it renders, the user assumes the
capability exists. Every ghost control is a support ticket.

---

## The census

Report this category as a count first, then the individual findings. The ratio is
what makes it legible at a glance:

```
Interactive elements    47
  Connected             39
  Suspicious             5
  Dead                   3
```

**Connected** — leads to a handler that does real work
**Suspicious** — handler exists but its effect could not be traced
**Dead** — no handler, or a provably empty one

Count `<button>`, `<a>`, `<Link>`, elements with click handlers, `role="button"`,
form submits, and framework equivalents (`v-on:click`, `on:click`, `@click`).

**Exclude** from the census: files matched by `false-positives.md` (tests, stories,
examples), and controls inside a component that is never imported anywhere.

---

## 1. Dead control

No handler at all, or one that provably does nothing.

```jsx
<button className="btn-primary">Invite team member</button>
<a href="#">Forgot password?</a>
<button onClick={() => {}}>Export</button>
```

**Check before flagging:** `disabled`, `aria-disabled`, `type="submit"` inside a form
that *does* have a submit handler, a click handler on an ancestor, or a native
behaviour that needs no JS (`<a href="/real/path">`, `<label htmlFor>`).

**Severity:** RISK. BLOCKER when the label promises something a user would act on and
stop worrying about — "Delete account", "Cancel subscription", "Download my data".

---

## 2. Orphan component

A component exists, is complete, and is imported by nothing.

**How to detect:** for each component file, grep for imports of it across the repo.
Zero importers means it never renders.

**Exclude:** entry points, route/page files (imported by the framework, not by code),
layouts, error/loading/not-found conventions, anything exported from a package's
public API, and dynamic imports by string path.

**Severity:** CLEANUP. This is dead weight, not a lie — the user never sees it.
It is worth reporting because it is a reliable fingerprint of AI-generated work:
files produced, never wired in, never removed.

---

## 3. Menu entry pointing nowhere

Navigation is the highest-visibility surface. A dead nav item is seen by every user
on every page.

```jsx
{ label: 'Reports', href: '/reports' }        // no /reports route
{ label: 'Settings', onClick: undefined }
```

**Severity:** BLOCKER when in primary navigation — it is the app's own table of
contents pointing at a missing chapter.

---

## 4. Empty, loading and error states missing

An async surface that renders only the success case.

```jsx
const { data } = useQuery(...);
return <Table rows={data.items} />;      // undefined while loading → crash
```

Three separate omissions, each its own finding:

- **No loading state** — blank screen or crash during fetch
- **No error state** — failure looks identical to "no data"
- **No empty state** — a new user sees an empty table with no explanation

**Severity:** RISK. BLOCKER when the missing guard throws (dereferencing possibly
undefined data, as above).

---

## 5. Control rendered without its permission check

An action visible to users who cannot perform it — a "Delete" button shown to
viewers, an "Admin" tab shown to everyone.

If the server enforces it, this is a UX problem: RISK.
If **only** the client hides it and the server does not check, that is an auth
finding — cross-reference `false-success.md` §6 and raise it to BLOCKER.

---

## Writing these findings

Group dead controls into one finding when they share a cause; separate them when a
reader would fix them in different places.

```
🟠 VP-007  Three controls have no handler
src/components/Toolbar.tsx:44   "Export CSV"
src/components/Toolbar.tsx:51   "Invite member"
src/app/login/page.tsx:88       "Forgot password?"

    <button className="btn-ghost">Export CSV</button>

None of the three has an onClick, a form association, or an ancestor handler.
All render unconditionally and are not disabled. A user clicking any of them
gets no feedback of any kind.
```
