import jwt from "jsonwebtoken";

export function getSession(req: Request) {
  const token = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!token) return null;

  const payload = jwt.decode(token) as { sub: string; role: string };
  return { userId: payload.sub, role: payload.role };
}
