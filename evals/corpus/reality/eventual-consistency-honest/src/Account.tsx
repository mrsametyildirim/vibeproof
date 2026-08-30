import { toast } from "sonner";

export function DangerZone({ user }) {
  async function requestDeletion() {
    const res = await fetch("/api/account/deletion-requests", { method: "POST" });
    if (!res.ok) return toast.error("Could not schedule deletion");
    toast.success("Deletion scheduled — your account closes in 30 days");
  }
  return <button onClick={requestDeletion}>Request account deletion</button>;
}
