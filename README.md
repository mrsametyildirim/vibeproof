<div align="center">

# VibeProof

### Your app looks done. Prove it.

Finds fake features, dead UI, fake persistence, broken wiring and false-success
flows in AI-generated apps.

**Zero config. Zero dependencies. Zero trust.**

</div>

---

Your AI said it's done.
Your UI looks done.

Is it actually done?

```
/vibeproof
```

That's it. No npx. No API key. No setup.

---

## The problem

Linters inspect your code. VibeProof inspects your **product promises**.

Vibe-coded apps rarely fail because of a syntax error. They fail because something
looks finished and isn't:

- `Delete Account` → `onClick={() => {}}`
- `Save` → updates React state, never reaches the server
- `Payment successful` → toast fires before the API responds
- Dashboard numbers → a hardcoded array
- `Export CSV` → no handler
- `/settings` in the nav → no such route
- Backend throws → `catch { return { success: true } }`
- Edit profile → works, until you refresh

None of that is a bug a linter can see. Every one of it ships.

---

## What it does

VibeProof reads your repo, works out what the app **claims** to do, then follows
each claim through the code:

```
BUTTON → HANDLER → API CALL → SERVER ROUTE → VALIDATION
       → DATABASE → RESPONSE → UI FEEDBACK
```

Wherever that chain breaks, it tells you the file and the line.

---

## Example output

```
╭──────────────────────────────────────╮
│              VIBEPROOF               │
│                                      │
│         REALITY SCORE  64/100        │
│                🟠 VIBEY              │
╰──────────────────────────────────────╯

18 product promises traced

  ✅  11  PROVEN
  ⚠️   2  UNPROVEN
  🎭   3  FAKE
  💥   2  BROKEN

─────────────────────────────────────────
BIGGEST LIE
─────────────────────────────────────────

src/components/Profile.tsx:118

    deleteAccount(user.id);
    toast.success("Account deleted successfully");

The UI reports success unconditionally. deleteAccount() is async and is never
awaited, so the message fires whether the request succeeds, fails, or never
resolves. A user who sees this believes their account is gone.

─────────────────────────────────────────
SHIP VERDICT
─────────────────────────────────────────

❌ DO NOT SHIP

Your app looks more complete than it actually is.
```

[Full example report →](examples/sample-report.md)

---

## Install

```bash
git clone https://github.com/YOUR_USER/vibeproof.git
cd vibeproof && ./install.sh
```

Or copy the skill folder yourself:

```bash
cp -r skills/vibeproof ~/.claude/skills/        # Claude Code
cp -r skills/vibeproof ~/.cursor/skills/        # Cursor
cp -r skills/vibeproof ~/.codex/skills/         # Codex
```

It is one `SKILL.md` plus six reference files. Nothing to build, nothing to run,
nothing that phones home.

---

## Usage

| Command | What it does |
|---|---|
| `/vibeproof` | Audit the whole repository |
| `/vibeproof diff` | Audit only what changed vs. the default branch |
| `/vibeproof feature checkout` | Trace one flow end to end |

```
/vibeproof feature authentication

AUTHENTICATION — REALITY

  Signup         ✅ PROVEN
  Login          ✅ PROVEN
  Logout         ✅ PROVEN
  Reset password 🎭 FAKE       success toast, no send call
  Email verify   ⚠️ UNPROVEN   token generated; consumer not found
  Admin guard    💥 BROKEN     client-only check
```

---

## What it checks

| Category | Catches |
|---|---|
| 🎭 **Fake Features** | Hardcoded data, no-op handlers, mock responses, simulated delays, hardcoded IDs and URLs |
| 🔌 **Broken Wiring** | Links to missing routes, calls to missing endpoints, undefined handlers, uninstalled imports |
| 🤥 **False Success** | Success before `await`, `catch` returning success, ignored HTTP status, swallowed errors |
| 💾 **Fake Persistence** | State-only saves, deletes that only filter an array, uploads that never upload |
| 💀 **Ghost UI** | Dead buttons, orphan components, nav entries to nowhere, missing loading/error/empty states |

---

## Reality Score

| Score | Band |
|---|---|
| 90–100 | 🟢 REAL |
| 75–89 | 🟡 MOSTLY REAL |
| 50–74 | 🟠 VIBEY |
| 25–49 | 🔴 MOSTLY FAKE |
| 0–24 | 🎭 BEAUTIFUL LIE |

The score is arithmetic, not opinion: every finding carries a fixed penalty, so the
same commit always scores the same. The ship verdict is decided by blockers alone —
a good score cannot override a blocker.

---

## Two rules it never breaks

**1. It never modifies your code.**
VibeProof reads, traces and reports. An auditor that also patches loses the ability
to be trusted about what was broken. You fix things afterwards, deliberately:

```
fix VP-003
```

**2. It never reports what it cannot quote.**
Every finding carries the file, the line, and the actual source. A finding it cannot
prove is downgraded to `UNPROVEN` and says what would confirm it. Every report ends
with a coverage section listing what it could *not* check.

A tool that cries wolf gets uninstalled after one run.

---

## What it is not

Not a linter. Not a security scanner. Not a code reviewer.

It will not tell you your component is too long, your tests are thin, or your
dependencies are out of date. Other tools do that well.

It answers one question: **is the thing on the screen actually connected to anything?**

---

## License

MIT
