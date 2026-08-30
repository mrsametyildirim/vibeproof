# A real audit

Not a mock-up. This is an actual `/vibeproof` run against a production Next.js
tool site — 2,584 source files, 95 routes, deployed and serving users.

The repository is anonymised; the findings are verbatim.

---

```
REALITY SCORE  87/100      🟡 MOSTLY REAL

12 promises traced      11 proven      1 broken
1 blocker   0 risks   1 cleanup

❌ DO NOT SHIP — your login button goes nowhere.
```

---

## 🔴 VP-001 · Login button links to a route that does not exist

`src/components/layout/Header.tsx:169` and `:232`

```jsx
<Link href="/hesap" className="btn-login">
  <span>Sign in</span>
</Link>
```

Four independent checks, all negative:

| Check | Result |
|---|---|
| `src/app/hesap/` directory | does not exist |
| Any `page.tsx` matching the path | none found |
| `next.config.ts` rewrites | only `/bgremoval/:path*` → external CDN |
| `middleware.ts` matcher | covers only `/admin/*` and `/api/metrics/summary/*` |

And the decisive one — the production build enumerates every route it generated:

```
✓ Compiled successfully in 7.6s
✓ Generating static pages (95/95)
```

`/hesap` appears **zero times** in that list.

The header renders on every page, desktop and mobile. Every visitor who tries to
sign in gets a 404.

---

## 🟡 VP-002 · Orphan stub module

`src/lib/vocalSeparator.ts` — 266 lines, 7 `TODO`s, imported by nothing.

---

## What was *not* reported — and why that matters more

This audit came within one step of filing two false accusations. The procedure
stopped it twice.

**First near-miss.** `vocalSeparator.ts` has seven `TODO`s marking unimplemented
core functions, and there is a `/vokal-ayir` page in the route table. The obvious
conclusion: a shipped tool with a stubbed engine.

Tracing the import graph showed the module is imported by **nobody**. Dead code —
a cleanup, not a blocker.

**Second near-miss.** Reading further, the stub is worse than empty. It drives a
progress bar through realistic stages, sets fabricated quality metrics
(`siSDR_vocals = 10.2`, commented "Placeholder metrics"), and returns five empty
blobs:

```js
onProgress?.("demux_inference", 0.5);
metrics.siSDR_vocals = 10.2;
return { vocals: new Blob([], {type: "audio/wav"}), /* … */ };
```

That is a textbook fake feature — *if a user can reach it.*

Opening the actual page component settled it:

```jsx
<button disabled style={{ cursor:"not-allowed", opacity:0.4 }}>
  Vokal ve Enstrüman Ayır
</button>
<p>Bu araç sunucu tabanlı AI gerektirdiğinden şu anda kullanılamamaktadır.</p>
```

The button is disabled. The page states plainly that the tool is unavailable and
links to three alternatives. **The product is honest.** The stub is unreachable
leftover code.

Reporting "fake feature: vocal separator returns empty audio" would have been
factually wrong and would have cost the tool its credibility on the first run.

---

## Also checked, nothing found

```
catch blocks returning success          0
fetch results used without status check 0   (2 fetch calls, 4 guards)
empty onClick handlers                  0
href="#"                                0
localhost / credential literals         0
console.log                             0
```

---

## Coverage

```
Routes mapped   95 / 95
Build           ✅ ran, passed (7.6s, 95 static pages)
Not checked     runtime behaviour, external URLs
```

---

The lesson this run teaches is the one in `references/false-positives.md`: the
value of an audit is not how much it finds. It is whether you can trust what it
reports. Two of the three things that looked like blockers here were not, and the
only way to know was to follow each one to the end.
