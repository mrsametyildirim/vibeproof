import { prisma } from "@/lib/db";

export async function POST(req: Request) {
  const { email } = await req.json();
  return Response.json(
    await prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`
  );
}
