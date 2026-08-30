import { toast } from "sonner";

export function DangerZone({ user }) {
  async function requestDeletion() {
    const res = await fetch("/api/account/deletion-requests", { method: "POST" });
    if (!res.ok) return toast.error("Could not delete account");
    toast.success("Your account has been permanently deleted");
  }
  return <button onClick={requestDeletion}>Delete account</button>;
}
