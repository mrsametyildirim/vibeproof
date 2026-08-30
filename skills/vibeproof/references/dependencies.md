# Dependencies and Supply Chain

The one area where VibeProof **cannot** reason its way to an answer.

Whether `lodash@4.17.20` has a known vulnerability is not deducible from the code.
It is a fact about a database that changes daily, and any model that produces a CVE
number from memory is producing fiction — plausible, well-formatted, and wrong.

So this category has a hard rule:

> **Every vulnerability finding here comes from a tool that was actually run.**
> No advisory database, no finding. Not a guess, not a recollection, not a
> "commonly known" issue.

That makes dependency findings the only ones in this tool that are routinely
`● RUNTIME VERIFIED` — the audit ran a command and read the output.

---

## Run the ecosystem's own auditor

Non-destructive, offline-capable where noted, no installs:

| Ecosystem | Command |
|---|---|
| npm | `npm audit --json` |
| pnpm | `pnpm audit --json` |
| yarn (berry) | `yarn npm audit --json` |
| Python | `pip-audit --format json` · `uv pip audit` |
| Rust | `cargo audit --json` |
| Go | `govulncheck ./...` |
| Ruby | `bundle audit check` |
| PHP | `composer audit --format=json` |
| .NET | `dotnet list package --vulnerable --include-transitive` |
| Anything | `osv-scanner --lockfile=<path>` |

Prefer `osv-scanner` when several ecosystems are present — one tool, one format.

If none of them is available, or the machine is offline, the answer is:

```
⚠️ UNVERIFIED   Dependency vulnerabilities not checked: no auditor available
                (`npm audit` requires network access).
                Run `npm audit` and re-run this section.
```

That is an `INCONCLUSIVE` input to the verdict, not a clean bill of health. "We did
not check" and "there is nothing" stay different sentences here as everywhere else.

---

## Triage: the count is not the finding

`npm audit` on a mature project frequently returns dozens of advisories, most of
which do not matter. Pasting that list into a report is how a security section
becomes wallpaper.

For each advisory that is `high` or `critical`, answer three questions:

**Is it reachable?** A vulnerability in a package used only by the build, or only
by a test framework, does not ship. `npm audit` cannot tell the difference;
`dependencies` versus `devDependencies` plus the actual import graph can.

**Does the vulnerable path apply?** A ReDoS in a parser the app never calls, or a
prototype-pollution issue in a code path guarded by validated input, is real and
lower priority than the raw severity implies.

**Is there a fix?** `npm audit fix` availability, a patched version, or a
maintained fork. A finding with no remediation is still worth reporting, but it is
a different conversation.

Report shape:

```
🟠 axios 1.6.2 — CVE-2025-XXXXX (high)   ● RUNTIME VERIFIED
   Reachable: yes — imported by src/lib/api.ts, ships in the client bundle
   Fixed in:  1.7.4          Command: npm audit --json
   17 further advisories, all dev-only or unreachable — listed under Health.
```

Name the transitive parent when the direct dependency is innocent. "Update axios"
is actionable; "vulnerability in `follow-redirects`" is not, when nothing in
`package.json` mentions it.

---

## Supply chain, which is not the same thing

These are visible from the repository and do not need a database.

**No lockfile.** `package.json` without `package-lock.json`, `pnpm-lock.yaml` or
`yarn.lock` means every install resolves differently. Builds are not reproducible
and a compromised patch release lands silently. 🟠, and 🔴 if a deploy pipeline
runs `npm install` rather than `npm ci`.

**Install scripts.** `postinstall` in a dependency runs arbitrary code on every
machine that installs it, including CI. Worth noting when present in a package the
project added directly.

**Unpinned CI actions.** `uses: some/action@v1` follows a mutable tag. Whoever
controls that tag controls what runs with your secrets. Pinning to a commit SHA is
the fix. (Also covered as `VP-DP-005` in `deployment.md`.)

**Names worth a second look.** A dependency one character from a popular package,
or a scoped-looking name that is not scoped, is worth reading before it is
dismissed. Do not accuse — say what looks unusual and let the reader decide.

**Direct git or URL dependencies.** `"pkg": "github:someone/fork"` bypasses the
registry, its versioning and its revocation.

**Abandoned packages.** No release in years, archived upstream, or deprecated on
the registry. Not a vulnerability. A statement about who fixes the next one.

---

## What does not belong here

Version currency for its own sake. "12 packages have newer versions" is not a
finding, it is a `npm outdated` run, and putting it in a report trains the reader
to skim.

A major version behind **with a known vulnerability, or with a security fix in the
gap** is a finding. Being behind is not.
