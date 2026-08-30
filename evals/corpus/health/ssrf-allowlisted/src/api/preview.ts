const ALLOWED = new Set(["docs.example.com", "blog.example.com"]);

export async function POST(req: Request) {
  const { url } = await req.json();

  let target: URL;
  try { target = new URL(url); } catch { return new Response("bad url", { status: 400 }); }
  if (target.protocol !== "https:" || !ALLOWED.has(target.hostname)) {
    return new Response("host not allowed", { status: 400 });
  }

  const page = await fetch(target, { redirect: "error", signal: AbortSignal.timeout(5000) });
  return Response.json({ html: await page.text() });
}
