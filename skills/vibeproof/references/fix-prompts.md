# Fix Prompts

A finding the user cannot act on is half a finding.

The reality audit ends at a one-line direction, because the person reading it wrote
the code and knows where to go. Security is different: the reader often did not
write the code — an AI builder did — and the fix lives somewhere they have never
opened, like a database policy.

So the security mode ends each finding with a prompt they can paste back into the
tool that built the app.

---

## Still not a patch

VibeProof does not write the fix. It writes the **instruction**, the user runs it,
and then `verify` checks the result. That keeps the auditor and the fixer separate,
which is the whole reason the read-only rule exists.

The prompt is part of the finding, not a separate feature.

---

## What a fix prompt must contain

1. **The exact target** — table, route, file, symbol. Not "the auth logic".
2. **The required end state**, as conditions, not as code.
3. **Explicit limits** — what must not change.
4. **A demand to show the result**, so `verify` has something to check.

Point 3 is the one that gets skipped and the one that causes damage. An AI builder
told to "fix the RLS policy" will cheerfully rewrite three other tables.

---

## Per tool

The same finding, addressed to different audiences. Lovable and Bolt users work in
chat and may never see the file; Claude Code and Cursor users work in the repo.

### Lovable / Bolt / Replit

Conversational, names the resource, forbids collateral change.

```
Audit the Supabase row-level security policy for the "profiles" table.

Requirements:
- Enable RLS on the table.
- Authenticated users may SELECT only rows where auth.uid() = user_id.
- Users may UPDATE only their own row.
- Anonymous users must have no access.
- Do not expose the service_role key anywhere in client code.
- Preserve the existing schema and do not modify any other table.

When you are done, show me the exact SQL policies you created.
```

### Claude Code / Cursor

Points at the file, states the invariant, asks for the diff.

```
In app/api/projects/delete/route.ts the handler checks that a session exists but
never checks that the project belongs to that session's user.

Add the ownership predicate to the delete itself rather than as a separate
lookup, so there is no window between the check and the delete.

Do not change the response shape or the route signature. Show me the diff.
```

The difference is not tone for its own sake. A repo-aware agent should be told the
path and left to work; a chat builder needs the resource named because it has no
file tree in front of it.

---

## Verify

```
/vibeproof security verify VG-003
```

Re-runs the checks for that one finding against current code and reports what
changed:

```
VG-003 — profiles table readable across users

BEFORE   🔴 EXPOSED          ◉ STATIC VERIFIED
AFTER    🔒 SECURED          ◉ STATIC VERIFIED

  RLS enabled on profiles                    supabase/migrations/021_rls.sql:3
  SELECT policy: auth.uid() = user_id        :7
  UPDATE policy: auth.uid() = user_id        :14
  No anonymous grant found
```

Three rules keep this honest:

**Re-check, never remember.** Evidence belongs to a code state. A finding is
resolved because the checks pass now, not because the user said they fixed it.

**A partial fix is not a fix.** If RLS was enabled but the UPDATE policy is still
missing, the result is `⬇ PARTIALLY ADDRESSED` with the remaining gap named. A
finding does not get closed for effort.

**Say when you cannot tell.** If verification needs something unavailable — a
migration that has not run, a backend not present — the result is `❔ INCONCLUSIVE`.
That is the correct answer, and it is more useful than a green tick that means
nothing.

The loop this creates is the point:

```
scan → fix prompt → user applies it → verify → ship
```

Each step produces evidence. None of them produce a claim that something is safe.
