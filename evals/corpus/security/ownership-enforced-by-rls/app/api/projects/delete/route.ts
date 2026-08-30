import { createServerClient } from "@/lib/supabase-server";

export async function POST(req: Request) {
  const supabase = createServerClient();
  const { projectId } = await req.json();

  const { error } = await supabase.from("projects").delete().eq("id", projectId);
  if (error) return new Response(error.message, { status: 403 });
  return Response.json({ ok: true });
}
