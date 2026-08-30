# Secrets and Egress

Finding a key is the easy half. Every scanner does it, and most of what they find
is fine — an anonymous key is *supposed* to be in the client.

The two questions that matter:

1. **Which side of the wire is it on?**
2. **Where does it go from there?**

---

## Key semantics: not every secret is a secret

Report a key only after establishing what it is for. Getting this wrong in either
direction is expensive: a false alarm on a publishable key destroys trust in the
report, and shrugging at a service-role key ships a disaster.

| Key | Belongs in the client? | If exposed |
|---|---|---|
| Supabase `anon` | **Yes, by design** | Nothing — row policies are the control |
| Supabase `service_role` | Never | Bypasses every row policy. Total database access |
| Firebase web config | **Yes, by design** | Nothing — security rules are the control |
| Firebase Admin SDK credential | Never | Full project access |
| Stripe publishable (`pk_`) | Yes | Nothing |
| Stripe secret (`sk_live_`) | Never | Charges, refunds, customer data |
| Clerk publishable | Yes | Nothing |
| Clerk secret | Never | Session forgery |
| OpenAI / Anthropic / Gemini / Groq / Mistral | Never | Billed to the owner, unmetered |
| ElevenLabs / Replicate | Never | Billed to the owner |
| AWS `AKIA…` | Never | Depends on the policy; assume the worst |

A finding that says "anon key found in client code" is noise. Say nothing, or say
what would actually matter — that the anon key is only as safe as the row policies
behind it, which is a `platform-supabase.md` question.

---

## Which side of the wire

Source location is not the answer. The framework decides what ships.

**Public-prefix inlining.** These are compiled into the bundle by design:

```
NEXT_PUBLIC_*        Next.js
VITE_*               Vite
REACT_APP_*          CRA
PUBLIC_*             SvelteKit, Astro
EXPO_PUBLIC_*        Expo
NUXT_PUBLIC_*        Nuxt
GATSBY_*             Gatsby
```

A secret behind one of these prefixes is exposed even though the source says
`process.env`. This is the single most common way an AI-assembled app leaks a key:
the generator needed the value in a component, the build complained, and adding
the prefix made the error go away.

```js
// EXPOSED — the prefix is the bug
const admin = createClient(url, process.env.NEXT_PUBLIC_SERVICE_ROLE!)
```

**Server-only contexts** that do not ship: API routes, server actions
(`"use server"`), `getServerSideProps`, middleware, workers, `+page.server.ts`,
Django/Rails/FastAPI handlers.

**Client contexts** that do: anything with `"use client"`, components, hooks,
inline `<script>`, service workers, anything imported by them.

Check the import graph, not the folder name. A server-only module imported by a
client component ships.

---

## Bundle verification — the strongest evidence available

If a build command exists and is non-destructive, run it and grep the output.

```
Command:  npm run build
Observed: sk_live_ prefix present in .next/static/chunks/app/page-4f2b.js
Evidence: ● RUNTIME VERIFIED
```

This is worth doing because it settles the argument. Reading source and reasoning
about what the bundler will inline is `STATIC VERIFIED`; finding the literal in the
built artifact is `RUNTIME VERIFIED`, and nobody argues with it.

Never print the secret. The prefix, the file, the fact. Nothing else — a report is
a document people paste into chat.

---

## Git history

Removing a key from a file does not remove it from the repository. If it was ever
committed and the repo is public, treat it as compromised.

```
git log -p -S 'sk_live_' -- .env
git log --all --diff-filter=D --name-only | grep -i env
```

The finding is not "there is a key in history". It is:

```
🔴 Stripe secret key was committed in 3f21a9c and later removed.
   The repository is public. Removing the file does not remove the object.
   This key must be rotated; deleting it again achieves nothing.
```

Rotation is the fix. Say so, because "remove it from history" is the answer people
reach for and it is the wrong one for a key that was already public.

---

## Egress: where does the value go

This is the part general scanners skip, and it is where AI-assembled apps actually
lose data. The key is stored correctly, and then something sends it somewhere.

Sensitive sources: environment secrets, session tokens, password fields, API keys,
personal data, uploaded file contents.

Sinks worth following:

| Sink | Why |
|---|---|
| `console.log` / `console.error` | Ships to the browser console, and to log aggregators |
| Analytics and error reporting | Sentry, PostHog, LogRocket, Datadog — breadcrumbs and context objects routinely carry request bodies |
| `fetch` to a third-party host | Especially one that is not the app's own API |
| `localStorage` / `sessionStorage` | Readable by any script on the page |
| Cookies without `HttpOnly` | Same |
| URL query strings | Recorded in server logs, referrer headers, browser history |
| LLM prompts | A prompt built from user records sends those records to the model provider |
| Client-side error boundaries | Often serialise the whole state object |

```js
// EXPOSED — the token ends up in the analytics vendor's storage
Sentry.setContext("auth", { token: session.access_token });
```

The LLM sink deserves attention in this class of app specifically, because it is
so easy to write:

```js
// review before shipping — the prompt carries whatever these fields hold
const prompt = `Summarise this customer: ${JSON.stringify(customer)}`;
```

Whether that is a finding depends on what is in `customer` and what the product
told the user. Trace it; do not assume either way.

---

## What suppresses a finding

- The value is a documented publishable key (see the table)
- The literal is a placeholder: `sk_live_xxx`, `your-key-here`, `<REDACTED>`,
  `example`, obvious repetition like `aaaaaaaa`
- It is in `.env.example`, documentation, or a test fixture **and** the file is not
  shipped
- It is a public identifier that only looks like a secret: a project ref, a
  publishable measurement ID

None of these suppress the finding if the value is reachable in the production
bundle. Location lowers suspicion; reachability decides.
