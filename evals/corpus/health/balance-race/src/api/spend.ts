export async function POST(req: Request, session: Session) {
  const { amount } = await req.json();

  const user = await db.user.findUnique({ where: { id: session.userId } });
  if (user.credits < amount) return new Response("insufficient", { status: 402 });

  await db.user.update({
    where: { id: session.userId },
    data: { credits: user.credits - amount },
  });
  return Response.json({ ok: true });
}
