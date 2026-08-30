# Negative Proof

Some findings claim something **is not there**:

- "this route does not exist"
- "no handler is wired to this button"
- "nothing consumes this token"
- "the change is never persisted"
- "no endpoint answers this call"

Absence is much harder to establish than presence. To prove a route exists you find
it once. To prove it does not exist you have to have looked everywhere it could
have been — and modern frameworks have a lot of places.

**This is the finding class most likely to be wrong.** It gets its own standard.

---

## The rule

> A finding that rests on absence may not be reported as BROKEN or FAKE until the
> search below has been carried out and its scope stated in the report.
>
> If the search cannot be completed, the product status is **UNVERIFIED**, not
> BROKEN.

Not finding something is a fact about your search. It becomes a fact about the code
only after the search was good enough to be worth reporting.

---

## Before declaring a route absent

Frameworks resolve URLs through many mechanisms. Check the ones that apply:

| Mechanism | Where to look |
|---|---|
| Literal file route | `app/`, `pages/`, `routes/`, `src/routes/` |
| Route group | `app/(marketing)/checkout/` — parentheses do not appear in the URL |
| Dynamic segment | `[id]`, `[...slug]`, `:id`, `<int:pk>` |
| Catch-all / optional catch-all | `[[...slug]]` |
| Rewrite | `next.config.js` `rewrites()`, `vercel.json`, `netlify.toml`, `_redirects` |
| Redirect | same files, plus framework-level redirect config |
| Proxy | `vite.config`, `webpack devServer`, nginx/Caddy config |
| Middleware | `middleware.ts`, request interceptors, `before_request` |
| Server action | a function with `"use server"`, invoked without a URL at all |
| RPC-style call | tRPC, gRPC, GraphQL resolver — there may be no REST route by design |
| Generated client | an SDK whose methods map to routes defined elsewhere |
| Another workspace package | `apps/api`, `packages/server` — see below |
| External backend | a different repository or a hosted service |

A `/checkout` link is not broken because `app/checkout/page.tsx` is missing. It is
broken when none of the above resolves it.

---

## Before declaring a handler or consumer absent

- Search the **symbol**, not just the filename.
- Follow re-exports and barrel files (`index.ts` that re-exports everything).
- Check aliases in `tsconfig.json` `paths`, `jsconfig`, bundler `resolve.alias`.
- Check dependency injection, decorators, and annotation-based registration
  (`@Controller`, `@app.route`, Rails routes file, Spring component scan).
- Check configuration-driven registration — handlers listed in a config array or
  loaded from a directory at runtime.
- Check feature flags and environment branches. Code behind a disabled flag exists;
  whether it is *reachable* is a separate question, and the answer belongs in the
  finding.

---

## Monorepos

If any of these exist, the current package is probably not the whole product:

```
package.json → "workspaces"
pnpm-workspace.yaml
turbo.json
nx.json
lerna.json
go.work
Cargo.toml → [workspace]
```

A frontend promise can legitimately terminate in a sibling package:

```
apps/web  →  packages/api-client  →  apps/api
```

Trace across the boundary before concluding the chain ends. If the sibling package
is not present in what you were given, that is a coverage statement — say the
backend was unavailable — not a broken-wiring finding.

---

## What goes in the report

State the search scope in one line so the reader can check your work:

```
Negative proof:
searched app routes, route groups, dynamic segments, next.config rewrites,
redirects and the two workspace packages; no resolver for /checkout found.
```

This is the factual scope of what you looked at. It is not your reasoning, and it
is not a narrative — one line, the places searched, the result.

If the line would have to say "searched app/checkout/page.tsx", the search was not
good enough to support the finding.

---

## When the search cannot be completed

Downgrade, and say why:

```
⚠️ UNVERIFIED   /checkout — no local resolver found, but next.config.js references
                an external billing host that is not part of this repository.
```

That is a useful, honest report. "BROKEN: route missing" would have been a guess
wearing a verdict's clothes.

---

## The asymmetry to remember

Proving presence needs one piece of evidence.
Proving absence needs an argument about completeness.

Treat them differently, and the tool stays credible on the findings that matter
most — because "the route you link to does not exist" is exactly the kind of
finding that gets a release stopped.
