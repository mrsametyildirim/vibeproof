# Deployment and Transport

Configuration that ships with the repository and decides what the running app
allows. Small files, few lines each, and nothing in the application code reveals
that any of it is wrong.

Everything here has a stable rule ID so it can be suppressed narrowly and tracked
across runs — see `rule-ids.md`.

---

## Cookies and sessions — `VP-DP-001`

```js
res.cookie("session", token, { maxAge: 604800000 });
```

Three flags decide whether that session is stealable:

| Flag | Without it |
|---|---|
| `httpOnly` | Any script on the page can read the token. One XSS becomes account takeover |
| `secure` | The cookie travels over plain HTTP if anything downgrades |
| `sameSite` | Cross-site requests carry it — the CSRF precondition |

`httpOnly` missing on a session cookie is 🔴. On a theme preference it is nothing.
The flag is not the finding; what the cookie authorises is.

The same question applies to a token in `localStorage`: readable by every script on
the page, by design. Sometimes a deliberate trade, often nobody chose it.

## CORS — `VP-DP-002`

```js
app.use(cors({ origin: "*", credentials: true }));
```

`*` alone is usually fine — a public read API. `*` **with** `credentials: true` is
the finding: it invites any origin to make authenticated requests. Browsers reject
that exact combination, which is a hint about how bad it is, and frameworks that
reflect the request origin instead reproduce it while passing the browser check:

```js
app.use(cors({ origin: (o, cb) => cb(null, true), credentials: true }));  // same thing
```

## TLS verification turned off — `VP-DP-003`

```python
requests.get(url, verify=False)
```
```js
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
rejectUnauthorized: false
```

Always the same story: it was failing locally against a self-signed certificate,
this made the error go away, and it shipped. Certificate validation is the entirety
of what TLS protects against an active attacker.

🔴 when the target is external or carries credentials. 🟡 when it is scoped to a
local development host and cannot reach production.

## JWT — `VP-DP-004`

```js
jwt.verify(token, secret, { algorithms: ["none"] });   // no signature at all
jwt.decode(token);                                     // decode is not verify
const secret = "secret";                               // brute-forceable
```

`jwt.decode()` where `jwt.verify()` was meant is the most common of the three and
the easiest to misread, because the code looks like it is doing something. It
parses the token and checks nothing — the payload is whatever the caller wrote,
including `role: "admin"`.

## CI/CD permissions — `VP-DP-005`

```yaml
permissions: write-all
on: pull_request_target
```

`pull_request_target` runs with repository secrets **in the context of the base
repository** while checking out a pull request's code. Combined with a checkout of
`github.event.pull_request.head.sha`, anyone who opens a PR from a fork runs their
own code with your secrets. It is a well-documented pattern and it appears
constantly, because it is the fix people find when a workflow cannot see secrets.

Also: a third-party action pinned to a mutable tag (`@v1`, `@main`) rather than a
commit SHA, and a secret echoed into a log line.

## Containers — `VP-DP-006`

```dockerfile
FROM node:20
COPY . .
CMD ["node", "server.js"]
```

No `USER` directive means the process runs as root. Add to that a `COPY . .` with
no `.dockerignore`, and `.env` and `.git` are now inside the image.

🟠 for root. 🔴 for secrets baked into a layer, because layers are distributed and
deleting a file in a later layer does not remove it from the earlier one — the same
shape as the git-history problem in `secrets-and-egress.md`.

## Debug left on — `VP-DP-007`

```python
DEBUG = True
ALLOWED_HOSTS = ["*"]
```

Framework debug pages render stack traces, settings, and often environment
variables to whoever triggers the error. Only a finding if it can be on in
production: a value hardcoded `True` qualifies; one read from an environment
variable does not, unless the deployment config sets it.

---

## Scope

This file stops here deliberately.

Not included: dependency CVEs, generic SQL-injection sweeps of every query,
cryptographic review, compliance checklists, performance, maintainability. Those
are other tools' jobs and doing them badly here would dilute the findings that stop
a release.

What earns a place is configuration that (a) ships in the repository, (b) decides
what the running application permits, and (c) an AI builder plausibly wrote while
making an error go away. Everything above meets all three.
