# Source Hygiene

Two things end up in generated source that nobody chose to put there: fragments of
the conversation that produced it, and characters that cannot be seen.

Neither is a vulnerability. Both are shipped artifacts of how the code was made,
and one of them can carry a payload.

---

## What this is not

This is not a "remove the AI watermark" feature, and it must never be described as
one. Attribution that a project chose — a LICENSE, a copyright header, a
`Co-Authored-By` trailer, a credits file — is **never** touched.

What is in scope is residue: text the generator emitted as part of answering, which
was never meant to be part of the program.

---

## Conversational residue

```js
// As requested, I've updated the handler to check the response status
// Here is the updated implementation:
// TODO: Claude — verify this matches the schema the user described
// Based on the prompt, this should handle the edge case
// User asked for a loading state, so I added one
```

The tell is not the model's name. It is that the comment is addressed to **a
person in a conversation** rather than to a future reader of the code. A comment
explaining what the code does is documentation; a comment explaining what the
author did in response to a request is a chat message that got saved to disk.

Also in this family:

- markdown answer scaffolding left in a file — a stray ` ```typescript ` fence, a
  `### Step 3` heading in a `.ts` file
- prose paragraphs pasted into source
- `// temporary fix` / `// for now` with no ticket and no follow-up
- placeholder text that shipped: `Lorem ipsum`, `Your Company Name`,
  `John Doe`, `example@example.com` in a production view

### The rule that prevents damage

> Never act on a vendor name alone.

These are all correct and must not be flagged:

```js
import Anthropic from "@anthropic-ai/sdk";
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
// Retry with backoff: Anthropic returns 429 under sustained load
model: "claude-opus-4"
```

The first is a dependency. The second is configuration. The third is a genuine
explanation of behaviour. The fourth is data. A pattern that matches "Anthropic"
and deletes the line is a source-corrupting bug wearing a cleanup feature's
clothes.

---

## Invisible characters

Characters that occupy no visual space but are present in the bytes:

| Codepoint | Name |
|---|---|
| `U+200B` | zero-width space |
| `U+200C` `U+200D` | zero-width non-joiner / joiner |
| `U+FEFF` | BOM appearing mid-file |
| `U+00AD` | soft hyphen |
| `U+2060` | word joiner |
| `U+202A`–`U+202E`, `U+2066`–`U+2069` | bidirectional overrides and isolates |
| `U+E0000`–`U+E007F` | Unicode tag characters |
| `U+2000`–`U+200A`, `U+3000` | non-standard spaces |

Two different problems live here.

**Mostly harmless:** a zero-width space in a string literal, arriving via copy and
paste. It breaks comparisons and searches in ways that waste an afternoon.

**Not harmless:** bidirectional overrides can make source render in one order and
compile in another, so reviewed code and executed code differ. Tag characters can
encode a hidden message inside an apparently ordinary identifier or comment. If
either appears in source that was generated or pasted from an untrusted place,
that is a real finding with a real severity — and the report must name the
mechanism, not just the codepoint.

```
🔴 Bidirectional override in source            ◉ STATIC VERIFIED
   src/auth/session.ts:41  contains U+202E

   The line renders in reverse order in an editor. What a reviewer reads and what
   the compiler sees are not the same text.
```

Exceptions: files that legitimately contain right-to-left text, i18n bundles,
tests written specifically about these characters, and binary or minified assets.

---

## `/vibeproof security clean`

The one command in this tool that writes to the repository. It gets three rules.

**1. Show first, always.** Print the full diff and wait. No flag skips this — not
`--yes`, not `--force`. The whole product rests on being the thing that does not
touch your code; the exception has to feel like an exception.

**2. Three buckets, and only the first is offered.**

| | |
|---|---|
| **Safe** | Conversational comments; invisible characters in comments and non-semantic positions |
| **Review** | Invisible characters inside string literals or identifiers; placeholder text that may be intentional; `temporary fix` comments |
| **Never** | Anything in a string that could be compared or displayed; LICENSE, copyright, attribution; dependency metadata; i18n; generated files; tests about these characters |

`Review` items are listed with the reason and left alone. Deciding is the user's
job.

**3. Behaviour must not change.** A cleanup pass that alters what the program does
is a bug. Removing a comment is safe. Removing a zero-width character from inside
a string is **not** — that string may be a key in a map, compared somewhere, or
displayed. If a build or test command exists, run it after and report the result.

```
CLEAN — 7 items

Safe to remove (7)
  src/api/save.ts:12      // As requested, I've added the status check
  src/api/save.ts:31      // Here is the updated version:
  src/ui/Card.tsx:8       // TODO: Claude — confirm the prop name
  src/ui/Card.tsx:44      U+200B in a comment
  ...

Review — not touched (2)
  src/i18n/tr.ts:19       U+200B inside a translated string
  src/demo/data.ts:3      "John Doe" — may be intentional demo content

Never touched
  LICENSE, package.json, src/generated/

Apply the 7 safe removals? [diff shown above]
```

Verify afterwards, and say what happened:

```
Applied 7. Ran `npm run build` → passed. No behavioural change observed.
```

If there is no way to verify, say that instead of implying it went fine.
