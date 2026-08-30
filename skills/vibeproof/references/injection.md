# Injection and Untrusted Input

The classic vulnerability classes. Every SAST tool covers these; the difference
here is the same as everywhere else in this skill — **reachability and evidence**,
not pattern count.

A `String.format` around a query in a migration script nobody runs is not the same
finding as one in a login handler, and reporting them identically is how a security
section stops being read.

For every finding below, establish three things before writing it:

1. **Where does the value come from?** Request body, query string, header, cookie,
   uploaded file, database row written by another user, third-party API, model
   output. If it is a constant, there is no finding.
2. **Is the path reachable in production?**
3. **What does the worst input do?** That is the severity, not the class.

---

## SQL injection — `VP-IN-001`

```js
db.query(`SELECT * FROM users WHERE email = '${email}'`);          // EXPOSED
db.query("SELECT * FROM users WHERE email = ?", [email]);          // correct
```

ORMs are usually safe and have escape hatches that are not:

```js
prisma.$queryRawUnsafe(`SELECT * FROM t WHERE id = ${id}`);        // EXPOSED
prisma.$queryRaw`SELECT * FROM t WHERE id = ${id}`;                // tagged: parameterised
knex.raw(`... ${input}`);                                          // EXPOSED
```

The Prisma pair matters: `$queryRaw` as a tagged template parameterises;
`$queryRawUnsafe` with the same-looking interpolation does not. Read which one it
is before reporting.

Two more that hide: an **identifier** cannot be parameterised, so a sort column or
table name taken from the request must be validated against an allow-list; and a
`LIKE` pattern built from input is at minimum a ReDoS-adjacent problem.

🔴 when reachable with user input. Consequence is data disclosure or worse, so this
is a blocker, not a risk.

## Command execution — `VP-IN-002`

```js
exec(`convert ${req.body.filename} out.png`);                      // EXPOSED
execFile("convert", [filename, "out.png"]);                        // correct
```
```python
os.system("ping " + host)                                          # EXPOSED
subprocess.run(["ping", host], shell=False)                        # correct
```

`shell=True`, `os.system`, backticks and `eval` on anything derived from input.
Shell metacharacters (`;`, `|`, `$()`, newline) turn one argument into two
commands. Passing an argument array with no shell removes the class entirely.

Also: `eval`, `new Function`, `vm.runInNewContext`, `pickle.loads`, `yaml.load`
without `SafeLoader`, and Java/PHP deserialization of untrusted bytes. All the same
shape — untrusted data becomes executable.

🔴, always, when reachable.

## Path traversal — `VP-IN-003`

```js
fs.readFile(path.join(UPLOADS, req.params.name));                  // EXPOSED
```

`../../etc/passwd`, or an absolute path, because `path.join` resolves `..` happily.
The fix is to resolve and then verify containment:

```js
const p = path.resolve(UPLOADS, name);
if (!p.startsWith(path.resolve(UPLOADS) + path.sep)) return deny();
```

The same applies to writes, to archive extraction (zip-slip), and to any filename
that reaches storage.

## SSRF — `VP-IN-004`

```js
const data = await fetch(req.body.url);                            // EXPOSED
```

Underrated in cloud-hosted apps because the server can reach things the internet
cannot: `169.254.169.254` for instance credentials, internal services, databases on
a private network. Webhook testers, URL previews, image proxies and "import from
URL" features are where it lives.

An allow-list of hosts is the control. A block-list of `localhost` is not — DNS
names, redirects, IPv6 and decimal-encoded addresses all get around it.

## XSS — `VP-IN-005`

```jsx
<div dangerouslySetInnerHTML={{ __html: comment.body }} />          // EXPOSED
element.innerHTML = userValue;                                     // EXPOSED
<div v-html="content">                                             // EXPOSED
{{ content | safe }}                                               // EXPOSED (Jinja)
```

React, Vue, Svelte and Angular escape by default, so the finding is almost always
one of the explicit opt-outs above. Sanitising with DOMPurify before rendering is
the fix; "the content is ours" is not, once anyone else can write it.

Two AI-app-specific cases worth checking explicitly: **model output rendered as
HTML** (see `llm-boundary.md`), and markdown rendered with raw HTML enabled.

Also `javascript:` in an `href` built from input, and `target="_blank"` without
`rel="noopener"` on user-supplied links.

## Open redirect — `VP-IN-006`

```js
res.redirect(req.query.next);                                      // EXPOSED
```

Low severity alone, high when it is the `next` parameter on a login flow — that is
a credential-phishing primitive on your own domain. Validate against a list of
paths, or accept only relative ones.

## Mass assignment — `VP-IN-007`

```js
await db.user.update({ where: { id }, data: req.body });           // EXPOSED
```

Whatever the client posted becomes column values, including `role`, `isAdmin`,
`credits`, `emailVerified`. Related to `VP-AZ-002`, and the fix is the same: pick
fields explicitly, or validate with a schema that strips unknown keys.

---

## Before reporting

Run the finding through `false-positives.md` and, where the claim is that no
validation exists, through `negative-proof.md`. Validation frequently lives away
from the call site:

- a schema at the route boundary (`zod`, `pydantic`, `class-validator`)
- framework-level sanitisation or an ORM that parameterises
- middleware, a decorator, a `@Valid` annotation
- a database constraint or column type that makes the input impossible

A parameterised query reached through three helper functions still looks like
string concatenation at the outer layer. Follow it before writing the finding.
