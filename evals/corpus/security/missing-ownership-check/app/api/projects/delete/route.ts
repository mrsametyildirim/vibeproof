import { getSession } from "@/lib/auth";
import { db } from "@/lib/db";

export async function POST(req: Request) {
  const session = await getSession();
  if (!session) return new Response("Unauthorized", { status: 401 });

  const { projectId } = await req.json();
  await db.project.delete({ where: { id: projectId } });
  return Response.json({ ok: true });
}
