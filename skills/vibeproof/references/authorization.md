# The Trust Boundary

The signature finding of this mode:

> **UI auth is not authorization.**

An AI-assembled app almost always has authentication. Someone asked for login, and
login got built. What is usually missing is the check that this *particular* user
may touch this *particular* record — because no prompt ever said "and make sure
users cannot delete each other's projects".

The result passes every manual test. The developer is logged in as themselves, and
everything they can see is theirs.

---

## The chain

Authentication answers *who are you*. Authorization answers *may you*. Trace both:

```
UI
 ↓  does the control appear only for permitted users?      ← cosmetic
API
 ↓  is there a route-level guard?                          ← necessary
IDENTITY
 ↓  is the user derived from the SESSION, not the request? ← critical
OWNERSHIP
 ↓  does this record belong to that user?                  ← usually missing
EFFECT
```

The first hop is not a control. The last two are where the audit lives.

---

## Ownership: the check that is not there

```js
// EXPOSED — authenticated, not authorized
export async function POST(req) {
  const session = await getSession();
  if (!session) return unauthorized();

  const { projectId } = await req.json();
  await db.project.delete({ where: { id: projectId } });   // whose project?
  return ok();
}
```

Login is enforced. Ownership is not. Any authenticated user can delete any
project by changing one value in a request they are already allowed to make.

What makes it correct is a predicate tying the record to the session:

```js
await db.project.delete({ where: { id: projectId, userId: session.user.id } });
```

Report it as:

```
🔴 BROKEN AUTHORIZATION            ◉ STATIC VERIFIED
   app/api/projects/delete/route.ts:14

   Authentication is enforced; ownership is not. The project id comes from the
   request body and is used directly in the delete. An authenticated user can
   delete another user's project by changing one value.
```

Name the missing predicate. "Add an authorization check" is not actionable; "the
delete needs `userId: session.user.id`" is.

---

## Identity from the client

Anything the browser sends, the browser chose. These are the ones that keep
appearing:

```js
const userId = req.body.userId;          // EXPOSED — caller picks who they are
const role   = req.headers['x-role'];    // EXPOSED
const price  = req.body.price;           // EXPOSED — caller picks what to pay
const isAdmin = req.body.isAdmin;        // EXPOSED
```

Identity comes from the verified session or token. Price comes from the database.
Role comes from the server's own record of it.

The price case is worth calling out separately, because it looks like data flow
rather than auth:

```js
// EXPOSED — the amount is whatever the client posted
await stripe.checkout.sessions.create({
  line_items: [{ price_data: { unit_amount: body.amount } }]
});
```

---

## Client-side gates

```jsx
{user.role === "admin" && <AdminPanel />}
```

Fine as UI. A finding only when the API behind it is unguarded — and it usually is,
because the visible check felt like the check.

```js
// app/api/admin/users/route.ts — no guard at all
export async function GET() {
  return Response.json(await db.user.findMany());
}
```

Two rules keep this honest:

- Hiding a control is **never** a finding on its own. It is good UX.
- The finding is the unguarded endpoint. Quote both: the client-side gate that
  creates the impression, and the server route that does not enforce it.

Related patterns in the same family: `localStorage.getItem('role')`, a JWT decoded
in the browser and trusted, a middleware `matcher` that misses the route it was
written for, and a guard on `/admin` but not on `/admin/users`.

---

## Redirects are not guards

```jsx
useEffect(() => { if (!user) router.push('/login'); }, [user]);
```

The data was already fetched, and the page rendered before the redirect. If the
component's loader ran server-side without a check, the response contained the
data regardless of where the browser went next.

---

## Before reporting: the negative-proof problem

"There is no authorization check" is an **absence claim**. Apply
[negative-proof.md](negative-proof.md) before it becomes EXPOSED. Enforcement may
live somewhere you have not looked:

- middleware (`middleware.ts`, `before_action`, `@PreAuthorize`, dependencies)
- a database-level row policy — with Supabase RLS the check may legitimately not
  exist in application code at all
- an ORM extension, global scope, or query filter applied at the client level
- a gateway, reverse proxy, or platform-level rule
- a decorator or guard registered by convention
- a wrapper such as `withAuth(handler)` at the export

The Supabase case matters most here: an app can be entirely correct with no
ownership predicate in the route, because the policy enforces it in the database.
Check the migrations before writing the finding. Getting this wrong produces a
confident, prominent, completely false CRITICAL.

If the search cannot be completed, the status is `UNVERIFIED` — not EXPOSED.
