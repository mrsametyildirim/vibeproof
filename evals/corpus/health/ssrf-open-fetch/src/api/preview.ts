export async function POST(req: Request) {
  const { url } = await req.json();
  const page = await fetch(url);
  return Response.json({ html: await page.text() });
}
