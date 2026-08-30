export async function GET(req: Request) {
  const cursor = new URL(req.url).searchParams.get("cursor");
  const events = await db.event.findMany({
    take: 50,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    orderBy: { createdAt: "desc" },
  });
  return Response.json({ events, nextCursor: events.at(-1)?.id ?? null });
}
