export async function POST(req: Request, session: Session) {
  const { amount } = await req.json();

  // The condition is part of the write, so the check cannot be overtaken.
  const updated = await db.user.updateMany({
    where: { id: session.userId, credits: { gte: amount } },
    data: { credits: { decrement: amount } },
  });
  if (updated.count === 0) return new Response("insufficient", { status: 402 });

  return Response.json({ ok: true });
}
