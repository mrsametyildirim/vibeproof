import jwt from "jsonwebtoken";

export function getSession(req: Request) {
  const token = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!token) return null;

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!, {
      algorithms: ["HS256"],
    }) as { sub: string; role: string };
    return { userId: payload.sub, role: payload.role };
  } catch {
    return null;
  }
}
