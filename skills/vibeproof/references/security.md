# Security Preflight

`/vibeproof security`

VibeProof asks *does it actually work?* This mode asks the other half:

> **Is it safe to ship?**

Same tool, same evidence rules. A security finding gets no special licence to
guess — if anything the bar is higher, because a false "your keys are exposed"
costs more panic than a false "this button is dead".

---

## Why this belongs here and not in a scanner

There are good general security scanners. This is not one, and it should not grow
into one.

The gap it fills is specific: apps assembled by Claude, Cursor, Lovable, Bolt and
Replit fail in a recognisable way. The generator wires up something that works on
the happy path and leaves the trust boundary undefended, because nothing in the
prompt asked about it. The result looks finished, and the hole is not a subtle
cryptographic flaw — it is a service key in a client bundle, or an admin check
written in React.

That is the same failure this tool already exists for. A dead button lies about
what the product does; a client-side admin check lies about who the product lets
in. Both are gaps between the visible promise and the actual implementation.

---

## Never say "safe"

No static analysis can certify an application. The verdict vocabulary reflects that:

| ✅ | **NO SHIP-BLOCKING FINDINGS DETECTED** |
| ⚠️ | **SHIP WITH KNOWN GAPS** |
| ❔ | **INCONCLUSIVE** |
| ❌ | **DO NOT SHIP** |

There is no ✅ SAFE, and there never will be. "We found nothing" and "there is
nothing" are different statements, and a security report is the last place to blur
them. The `INCONCLUSIVE` rules from `report-format.md` apply here with more force,
not less: an unreadable backend, an unrunnable build, or an untraced critical flow
means the audit is unfinished.

---

## Status and evidence, same two axes

Product status becomes security status. Evidence level is unchanged:

| Status | Meaning |
|---|---|
| 🔒 **SECURED** | The boundary is enforced where it has to be |
| ⚠️ **UNVERIFIED** | Not enough of the boundary could be checked |
| 🔧 **MISCONFIGURED** | Enforcement exists but is set up so it does not hold |
| 🔴 **EXPOSED** | Something reachable is unprotected |

Evidence: ● RUNTIME VERIFIED · ◉ STATIC VERIFIED · ◐ PARTIAL · ○ SUSPECTED.

The distinction earns its keep immediately:

```
🔴 PUBLIC STORAGE BUCKET          ◉ STATIC VERIFIED
   supabase/migrations/018_storage.sql:24
   public = true

⚠️ POSSIBLE PUBLIC STORAGE        ○ SUSPECTED
   bucket named "public-uploads"; no policy file found
```

The second one is a guess about a name. It is reported, it is not scored, and it
can never be a blocker — exactly as `SUSPECTED` behaves everywhere else.

---

## Severity comes from consequence

Same rule as the reality audit. The category is not the severity.

| Finding | Consequence | Severity |
|---|---|---|
| Anon key in client code | Designed to be public | 🟡 not a finding at all |
| Service-role key in client code | Bypasses every row policy | 🔴 CRITICAL |
| Missing rate limit on a newsletter form | Spam | 🟠 |
| Missing ownership check on `deleteProject` | Any user deletes any project | 🔴 CRITICAL |
| `localhost` URL in a config default | Broken, not dangerous | 🟡 |

A CRITICAL requires the same five conditions as a BLOCKER: verified evidence,
production-reachable, real exposure, critical consequence, and a passed
[challenge](challenge.md).

---

## Order of work

1. **Identify the build.** Which generator, which stack, which auth, which storage.
   This decides which checks even apply — see `platform-supabase.md` and the
   generator notes there. Running Supabase policy checks against a Firebase app
   produces confident nonsense.

2. **Secrets and egress** — `secrets-and-egress.md`. Not just "is there a key" but
   *which side of the wire is it on, and where does it flow*.

3. **The trust boundary** — `authorization.md`. Authentication is not
   authorization, and a check written in a component is not a check.

4. **Platform configuration** — `platform-supabase.md`. The highest-yield area
   there is: row-level security is off on at least one table in the large majority
   of AI-generated apps, and with it off the anon key is a full read-write key
   handed to every visitor.

5. **The LLM boundary** — `llm-boundary.md`. A model may propose an action; it may
   never be the thing that decides the caller is allowed.

6. **Deployment and transport** — `deployment.md`. Cookies, CORS, TLS, JWT, CI
   permissions, containers. Configuration that ships and decides what the running
   app permits.

7. **Source hygiene** — `source-hygiene.md`. Prompt fragments, model-attribution
   comments and invisible characters left in shipped source.

8. **Fix prompts** — `fix-prompts.md`. A finding the user cannot act on is half a
   finding.

Findings carry stable rule IDs (`rule-ids.md`) so they can be tracked across runs
and suppressed narrowly — a rule and a target and a reason, never a bare directory.

---

## Biggest Exposure

The security counterpart to Biggest Lie. One per report, only from a verified
CRITICAL, omitted entirely when there is none.

```
─────────────────────────────────────────
BIGGEST EXPOSURE
─────────────────────────────────────────

src/lib/supabase.ts:7

    const admin = createClient(url, process.env.NEXT_PUBLIC_SERVICE_ROLE!)

The service-role key is read through a NEXT_PUBLIC_ variable, which Next.js
inlines into the client bundle. That key is designed to bypass row-level
security. Anyone who opens devtools has unrestricted read and write access to
every table.

Evidence: ◉ STATIC VERIFIED   Challenge: survived
```

Name the mechanism, not just the rule. "Service role key exposed" is a lint
message. The paragraph above is why someone stops the deploy.

---

## Read-only, with one exception

The audit never modifies code — same rule as always.

`/vibeproof security clean` is the single exception, and it is narrowly scoped to
source hygiene: comments and invisible characters, never logic. It shows the diff
and asks before touching anything. The rules are in `source-hygiene.md`, and they
are strict: a cleanup pass that changes behaviour is a bug, not a feature.
